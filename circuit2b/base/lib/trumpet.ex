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
    gpios = Enum.map(buttons(), fn {gpio, _config} -> setup_gpio(gpio) end)

    # We have to keep the GPIOs in state, otherwise we stop receiving messages!
    {:ok, %{active_tones: [], gpios: gpios}}
  end

  @impl true
  def handle_info({:circuits_gpio, gpio, _timestamp, 1}, %{active_tones: active_tones} = state) do
    {:noreply, Map.put(state, :active_tones, deregister_tone(tone(gpio), active_tones))}
  end

  @impl true
  def handle_info({:circuits_gpio, gpio, _timestamp, 0}, %{active_tones: active_tones} = state) do
    {:noreply, Map.put(state, :active_tones, register_tone(tone(gpio), active_tones))}
  end

  # --- Private Implementation ---

  defp register_tone(tone, active_tones) do
    case tone in active_tones do
      true -> active_tones
      false ->
        Pigpiox.Pwm.hardware_pwm(buzzer_gpio(), tone, @default_volume)
        [tone | active_tones]
    end
  end

  defp deregister_tone(_tone, active_tones) when length(active_tones) <= 1 do
    Pigpiox.Pwm.hardware_pwm(buzzer_gpio(), 0, 0)
    []
  end

  defp deregister_tone(tone, [active_tone | _ ] = active_tones) when tone == active_tone do
    active_tones = List.delete_at(active_tones, 0)
    Pigpiox.Pwm.hardware_pwm(buzzer_gpio(), List.first(active_tones), @default_volume)
    active_tones
  end

  defp deregister_tone(tone, active_tones) do
    active_tones
    |> Enum.reject(fn active_tone -> active_tone == tone end)
  end

  defp setup_gpio(gpio) do
    Logger.info("Setting up gpio: #{gpio}")
    {:ok, gpio_addr} = GPIO.open(gpio, :input, pull_mode: :pullup)
    Circuits.GPIO.set_interrupts(gpio_addr, :both)
    gpio_addr
  end

  defp tone(gpio), do: buttons()[gpio].tone
  defp buttons(), do: Application.get_env(:circuit2b, :buttons)
  defp buzzer_gpio(), do: Application.get_env(:circuit2b, :buzzer_gpio)

end
