defmodule Circuit2b.Trumpet do
  use GenServer

  require Logger
  alias Circuits.GPIO

  @default_volume 500_000 # 50%

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{})
  end

  # --- Callbacks ---

  @impl true
  def init(_) do
    # Initialize GPIOs
    gpios = Enum.map(buttons(), fn {gpio, _colour} -> setup_gpio(gpio) end)

    # We have to keep the GPIOs in state, otherwise we stop receiving messages!
    {:ok, %{active_colours: [], gpios: gpios}}
  end

  @impl true
  def handle_info({:circuits_gpio, gpio, _timestamp, 1}, %{active_colours: active_colours} = state) do
    {:noreply, Map.put(state, :active_colours, deregister_colour(colour(gpio), active_colours))}
  end

  @impl true
  def handle_info({:circuits_gpio, gpio, _timestamp, 0}, %{active_colours: active_colours} = state) do
    {:noreply, Map.put(state, :active_colours, register_colour(colour(gpio), active_colours))}
  end

  # --- Private Implementation ---

  defp register_colour(colour, active_colours) do
    case colour in active_colours do
      true -> active_colours
      false ->
        active_colours = [colour | active_colours]
        |> Enum.sort()

        Pigpiox.Pwm.hardware_pwm(buzzer_gpio(), tone(active_colours), @default_volume)
        active_colours
    end
  end

  defp deregister_colour(_colour, active_colours) when length(active_colours) <= 1 do
    Pigpiox.Pwm.hardware_pwm(buzzer_gpio(), 0, 0)
    []
  end

  defp deregister_colour(colour, active_colours) do
    active_colours = active_colours
    |> Enum.reject(fn active_colour -> active_colour == colour end)

    Pigpiox.Pwm.hardware_pwm(buzzer_gpio(), tone(active_colours), @default_volume)
    active_colours
  end

  defp tone([:blue]),                do: 262
  defp tone([:red]),                 do: 294
  defp tone([:yellow]),              do: 330
  defp tone([:blue, :red]),          do: 349
  defp tone([:blue, :yellow]),       do: 392
  defp tone([:red, :yellow]),        do: 440
  defp tone([:blue, :red, :yellow]), do: 494

  defp setup_gpio(gpio) do
    Logger.info("Setting up gpio: #{gpio}")
    {:ok, gpio_addr} = GPIO.open(gpio, :input, pull_mode: :pullup)
    Circuits.GPIO.set_interrupts(gpio_addr, :both)
    gpio_addr
  end

  defp colour(gpio), do: buttons()[gpio]
  defp buttons(), do: Application.get_env(:circuit2b, :buttons)
  defp buzzer_gpio(), do: Application.get_env(:circuit2b, :buzzer_gpio)

end
