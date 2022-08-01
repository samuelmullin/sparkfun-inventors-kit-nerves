defmodule Circuit2c.SimonClient do
  use GenServer

  require Logger
  alias Circuits.GPIO
  alias Circuit2c.SimonServer

  @default_volume 500_000 # 10%
  @interval_ms 250
  @buzzer_pin Application.get_env(:circuit2c, :buzzer_pin)

  @colours [:yellow, :blue, :red, :green]

  # Setup pin to name map (at compile time)
  @gpio_names @colours
  |> Enum.reduce(%{}, fn colour, acc -> Map.put(acc, Application.get_env(:circuit2c, String.to_atom("#{colour}_input_pin")), colour) end)

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # GenServer Callbacks
  @impl true
  def init(_) do
    # Initialize GPIOs for button/led for each colour
    gpios = Enum.reduce(@colours, %{}, fn colour, acc ->

      {:ok, input_gpio} = GPIO.open(input_pin(colour), :input, pull_mode: :pullup)
      Circuits.GPIO.set_interrupts(input_gpio, :both)
      {:ok, led_gpio} = GPIO.open(led_pin(colour), :output)

      config = %{
        input_gpio: input_gpio,
        led_gpio: led_gpio
      }

      Map.put(acc, colour, config)
    end)

    # Start the game
    start_game(gpios)

    # Enter game loop async so we can end our init process
    Task.async(fn -> game_loop(gpios) end)

    {:ok, %{gpios: gpios, input_state: :waiting}}
  end

  # Handle messages from circuits_gpio indicating our input state has changed
  @impl true
  def handle_info({:circuits_gpio, pin, _timestamp, gpio_state}, %{gpios: gpios, input_state: input_state} = state) do
    pin
    |> gpio_name()
    |> handle_gpio_state(gpio_state, input_state, gpios)

    {:noreply, state}
  end

  @impl true
  def handle_call(:waiting, _from, state) do
    {:reply, :ok, Map.put(state, :input_state, :waiting)}
  end

  @impl true
  def handle_cast(:accept_input, state) do
    {:noreply, Map.put(state, :input_state, :accept_input)}
  end

  # Private Implementation
  defp start_game(gpios) do
    SimonServer.start()
    start_sequence(gpios)
  end

  defp game_loop(gpios) do
    case SimonServer.game_status() do
      :next_sequence ->
        # Set waiting state and pause momentarily
        GenServer.call(__MODULE__, :waiting)
        Process.sleep(500)

        # Get next sequence and display for player
        SimonServer.next_sequence()
        |> handle_sequence(gpios)

      :next_button ->
        game_loop(gpios)
      :win ->
        win_sequence(gpios)
      :lose ->
        lose_sequence(gpios)
      :done ->
        :ok
    end

    # The game ended, start it again!
    start_game(gpios)
    game_loop(gpios)
  end

  defp handle_gpio_state(colour, 0, :accept_input, gpios) when colour in @colours, do: select_colour(colour, gpios)
  defp handle_gpio_state(colour, 1, :accept_input, gpios) when colour in @colours do
    deselect_colour(colour, gpios)
    SimonServer.validate_input(colour)
  end
  defp handle_gpio_state(name, _, _, _), do: :ok

  defp start_sequence(gpios) do
    Enum.each(@colours, fn colour ->
      Pigpiox.Pwm.hardware_pwm(@buzzer_pin, tone(colour), @default_volume)
      GPIO.write(gpios[colour][:led_gpio], 1)
      Process.sleep(100)
      Pigpiox.Pwm.hardware_pwm(@buzzer_pin, 0, 0)
      GPIO.write(gpios[colour][:led_gpio], 0)
      Process.sleep(100)
    end)

    Process.sleep(500)
  end

  defp win_sequence(gpios) do
    Enum.each([200, 300, 400], fn starting_tone ->
      @colours
      |> Enum.with_index()
      |> Enum.each(fn {colour, index} ->
        Pigpiox.Pwm.hardware_pwm(@buzzer_pin, starting_tone + (20 * index), @default_volume)
        GPIO.write(gpios[colour][:led_gpio], 1)
        Process.sleep(100)
        GPIO.write(gpios[colour][:led_gpio], 0)
      end)
    end)
    Pigpiox.Pwm.hardware_pwm(@buzzer_pin, 0, 0)
    Process.sleep(500)
  end

  defp lose_sequence(gpios) do
    Enum.each(1..20, fn num ->
      Pigpiox.Pwm.hardware_pwm(@buzzer_pin, 600 - (20 * num), @default_volume)
      GPIO.write(gpios[:red][:led_gpio], 1)
      Process.sleep(50)
    end)
    Pigpiox.Pwm.hardware_pwm(@buzzer_pin, 0, 0)
    GPIO.write(gpios[:red][:led_gpio], 0)
    Process.sleep(500)
  end

  defp handle_sequence(:win, gpios), do: win_sequence(gpios)
  defp handle_sequence(sequence, gpios) do
    sequence
    |> Enum.each(fn colour ->
      select_colour(colour, gpios)
      Process.sleep(@interval_ms)
      deselect_colour(colour, gpios)
      Process.sleep(@interval_ms)
    end)

    # Reset timer and accept input
    SimonServer.reset_timer()
    GenServer.cast(__MODULE__, :accept_input)
    game_loop(gpios)
  end

  defp select_colour(colour, gpios) do
    Pigpiox.Pwm.hardware_pwm(@buzzer_pin, tone(colour), @default_volume)
    GPIO.write(gpios[colour][:led_gpio], 1)
  end

  defp deselect_colour(colour, gpios) do
    Pigpiox.Pwm.hardware_pwm(@buzzer_pin, 0, 0)
    GPIO.write(gpios[colour][:led_gpio], 0)
  end

  # Helpers to fetch our config vars
  defp tone(colour), do: Application.get_env(:circuit2c, String.to_atom("#{colour}_tone"))
  defp led_pin(colour), do: Application.get_env(:circuit2c, String.to_atom("#{colour}_led_pin"))
  defp input_pin(name), do: Application.get_env(:circuit2c, String.to_atom("#{name}_input_pin"))
  defp gpio_name(pin), do: Map.get(@gpio_names, pin)

end
