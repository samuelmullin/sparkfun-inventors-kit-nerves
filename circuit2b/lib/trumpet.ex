defmodule Circuit2b.Trumpet do
  use GenServer

  require Logger
  alias Circuits.GPIO

  @default_volume 100_000 # 10%
  @buzzer_pin 13
  @pins %{
    26 => %{
      button: :red,
      tone: 262
    },
    21 => %{
      button: :blue,
      tone: 294
    },
    20 => %{
      button: :yellow,
      tone: 330
    },
    6 => %{
      button: :green,
      tone: 349
    }
  }

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{})
  end

  # Callbacks
  @impl true
  def init(_) do
    # Initialize Pins
    gpios = Enum.map(@pins, fn {pin, _config} -> setup_pin(pin) end)

    # We have to keep the GPIOs in state, otherwise we stop receiving messages!
    {:ok, %{active_tones: [], gpios: gpios}}
  end

  @impl true
  def handle_info({:circuits_gpio, pin, _timestamp, 1}, %{active_tones: active_tones} = state) do
    Logger.info("Deregister #{pin} #{@pins[pin].tone} #{inspect active_tones}")
    Logger.info("#{inspect(Circuits.GPIO.info())}")
    {:noreply, Map.put(state, :active_tones, deregister_tone(@pins[pin].tone, active_tones))}
  end

  @impl true
  def handle_info({:circuits_gpio, pin, _timestamp, 0}, %{active_tones: active_tones} = state) do
    Logger.info("Register #{pin} #{@pins[pin].tone} #{inspect active_tones}")
    Logger.info("#{inspect(Circuits.GPIO.info())}")
    {:noreply, Map.put(state, :active_tones, register_tone(@pins[pin].tone, active_tones))}
  end

  defp register_tone(tone, active_tones) do
    case tone in active_tones do
      true -> active_tones
      false ->
        Pigpiox.Pwm.hardware_pwm(@buzzer_pin, tone, @default_volume)
        [tone | active_tones]
    end
  end

  defp deregister_tone(_tone, active_tones) when length(active_tones) <= 1 do
    Pigpiox.Pwm.hardware_pwm(@buzzer_pin, 0, 0)
    []
  end

  defp deregister_tone(tone, [active_tone | _ ] = active_tones) when tone == active_tone do
    active_tones = List.delete_at(active_tones, 0)
    Pigpiox.Pwm.hardware_pwm(@buzzer_pin, List.first(active_tones), @default_volume)
    active_tones
  end

  defp deregister_tone(tone, active_tones) do
    active_tones
    |> Enum.reject(fn active_tone -> active_tone == tone end)
  end

  defp setup_pin(pin) do
    Logger.info("Setting up pin: #{pin}")
    {:ok, gpio} = GPIO.open(pin, :input, pull_mode: :pullup)
    Circuits.GPIO.set_interrupts(gpio, :both)
    gpio
  end

end
