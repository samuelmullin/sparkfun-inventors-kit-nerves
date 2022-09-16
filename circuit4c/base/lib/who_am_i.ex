defmodule Circuit4c.WhoAmI do
  use GenServer

  require Logger

  alias Circuits.GPIO
  alias LcdDisplay.HD44780.GPIO, as: LCD

  @default_words [
    "apple",
    "banana",
    "orange",
    "grape",
    "kiwi"
  ]

  @default_time_limit 30

  defmodule GameState do
    defstruct base_words: [],
              time_limit: 0,
              current_word: "",
              remaining_words: nil,
              round_number: 0,
              timer: 0,
              status: :waiting,
              lcd_ref: nil,
              button_ref: nil,
              buzzer_pin: nil
  end

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # --- Callbacks ---

  @impl true
  def init(config) do
    # Get our LCD config and start the LCD GenServer
    lcd_config = Application.fetch_env!(:circuit4c, :lcd_config)
    {:ok, lcd_ref} = LCD.start(lcd_config)

    # Get our button reference
    {:ok, button_ref} = GPIO.open(Application.fetch_env!(:circuit4c, :button_pin), :input, pull_mode: :pullup)

    GPIO.set_interrupts(button_ref, :falling)

    # Get our buzzer pin
    buzzer_pin = Application.fetch_env!(:circuit4c, :buzzer_pin)

    # Clear the screen
    LCD.execute(lcd_ref, :clear)

    # Print the first line
    LCD.execute(lcd_ref, {:print, "Press to start!"})

    state = struct(GameState, [
      lcd_ref: lcd_ref,
      button_ref: button_ref,
      buzzer_pin: buzzer_pin,
      time_limit: Keyword.get(config, :time_limit, @default_time_limit),
      base_words: Keyword.get(config, :words, @default_words)
    ])

    {:ok, state}
  end
  @impl true
  def handle_info({:circuits_gpio, _, _, _}, %GameState{status: :started} = state) do
    state = next_round(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:circuits_gpio, _, _, _}, %GameState{status: :waiting} = state) do
    state = start_game(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:circuits_gpio, _, _, _}, %GameState{} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:tick, %GameState{timer: 1, status: :started} = state) do
    Process.send_after(__MODULE__, :lose_sequence, 10)
    {:noreply, struct(state, [status: :lose])}
  end

  @impl true
  def handle_info(:tick, %GameState{status: :started} = state) do
    state = struct(state, [timer: state.timer - 1])
    update_display(state)
    Process.send_after(__MODULE__, :tick, 1000)

    {:noreply, state}
  end

  @impl true
  def handle_info(:tick, %GameState{} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:win_sequence, %GameState{status: :win} = state) do
    win_sequence(state)
    Process.send_after(__MODULE__, :reset, 1)
    {:noreply, struct(state, [status: :pending_reset])}
  end

  @impl true
  def handle_info(:lose_sequence, %GameState{status: :lose} = state) do
    lose_sequence(state)
    Process.send_after(__MODULE__, :reset, 1)

    {:noreply, struct(state, [status: :pending_reset])}
  end

  @impl true
  def handle_info(:reset, %GameState{status: :pending_reset} = state) do
    state = struct(state, [
      current_word: "",
      remaining_words: nil,
      round_number: 0,
      timer: 0,
      status: :waiting
    ])

    {:noreply, state}
  end

  # --- Private Implementation ---
  defp update_display(state) do
    LCD.execute(state.lcd_ref, {:set_cursor, 0, 0})
    LCD.execute(state.lcd_ref, {:print, String.pad_trailing(state.current_word, 16)})
    LCD.execute(state.lcd_ref, {:set_cursor, 1, 0})
    LCD.execute(state.lcd_ref, {:print, "R: #{pad_number(state.round_number)} T: #{pad_number(state.timer)}"})
  end

  defp pad_number(number), do: number |> Integer.to_string |> String.pad_leading(2, "0")

  defp start_game(state) do
    words = Enum.shuffle(state.base_words)
    state = struct(state, [remaining_words: words, timer: state.time_limit, round_number: 0, status: :started])
    Process.send_after(__MODULE__, :tick, 1100)
    LCD.execute(state.lcd_ref, :clear)
    next_round(state)
  end

  defp next_round(%GameState{remaining_words: [], status: :started} = state) do
    Process.send_after(__MODULE__, :win_sequence, 10)
    struct(state, [status: :win])
  end

  defp next_round(state) do
    [current_word | remaining_words] = state.remaining_words
    round_number = state.round_number + 1
    state = struct(state, [current_word: current_word, remaining_words: remaining_words, round_number: round_number])
    update_display(state)
    state
  end

  defp win_sequence(state) do
    LCD.execute(state.lcd_ref, :clear)
    LCD.execute(state.lcd_ref, {:set_cursor, 0, 0})
    LCD.execute(state.lcd_ref, {:print, "All Correct!!"})
    LCD.execute(state.lcd_ref, {:set_cursor, 1, 0})
    LCD.execute(state.lcd_ref, {:print, "Press to restart!"})
    Music.win_notes(state.buzzer_pin)
  end

  defp lose_sequence(state) do
    LCD.execute(state.lcd_ref, :clear)
    LCD.execute(state.lcd_ref, {:set_cursor, 0, 0})
    LCD.execute(state.lcd_ref, {:print, "Correct: #{pad_number(state.round_number)}"})
    LCD.execute(state.lcd_ref, {:set_cursor, 1, 0})
    LCD.execute(state.lcd_ref, {:print, "Press to restart!"})
    Music.lose_notes(state.buzzer_pin)
  end
end

defmodule Music do
  def win_notes(buzzer_pin) do
    Enum.each([162, 212, 249, 212, 249, 240, 249], fn note ->
      Pigpiox.Pwm.hardware_pwm(buzzer_pin, note, 5_000)
      Process.sleep(400)
      Pigpiox.Pwm.hardware_pwm(buzzer_pin, note, 0)
      Process.sleep(10)
    end)
  end

  def lose_notes(buzzer_pin) do
    Enum.each([249, 240, 249, 212, 249, 212, 162], fn note ->
      Pigpiox.Pwm.hardware_pwm(buzzer_pin, note, 5_000)
      Process.sleep(400)
      Pigpiox.Pwm.hardware_pwm(buzzer_pin, note, 0)
      Process.sleep(10)
    end)
  end
end
