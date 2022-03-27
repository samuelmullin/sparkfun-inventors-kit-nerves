defmodule Circuit1b.Potentiometer do
  use GenServer

  require Logger
  alias Circuits.I2C
  alias Circuits.GPIO

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # --- Public API ---

  def get_reading() do
    GenServer.call(__MODULE__, :get_reading)
  end

  # --- Callbacks ---

  @impl true
  def init(_) do
    # Open each LED GPIO for output
    leds = Enum.map(leds(), fn led ->
      {:ok, output_gpio} = GPIO.open(led[:gpio], :output)
      Map.put(led, :output_gpio, output_gpio)
    end)

    # Open I2C-1 for input
    {:ok, ads_ref} = I2C.open("i2c-1")

    # Kick off recursive task to blink our LED
    Enum.each(leds, fn led -> Task.async(fn -> blink_led(led) end) end)

    # Store our references in state so they don't get garbage collected
    {:ok, %{ads_ref: ads_ref, leds: leds}}
  end

  @impl true
  def handle_call(:get_reading, _from, %{ads_ref: ads_ref} = state) do
    # Get a reading from our potentiometer
    {:ok, reading} = ADS1115.read(ads_ref, adc1115_address(), {:ain0, :gnd}, adc_gain())
    {:reply, reading, state}
  end

  # --- Private Implementation ---

  defp blink_led(led) do
    # Get the reading and convert to a whole number between 0 and 1000
    reading = get_reading()
    blink_ms = round((((reading / max_reading()) * max_candence_ms()) + 50) * led[:cadence_multiplier])

    # Turn the led on and sleep
    GPIO.write(led[:output_gpio], 1)
    Process.sleep(blink_ms)

    # Turn the LED off and sleep
    GPIO.write(led[:output_gpio], 0)
    Process.sleep(blink_ms)

    # Start over
    blink_led(led)
  end


  defp adc1115_address, do: Application.get_env(:circuit1b, :adc1115_address)
  defp max_reading, do: Application.get_env(:circuit1b, :max_reading)
  defp adc_gain, do: Application.get_env(:circuit1b, :adc_gain)
  defp max_cadence_ms, do: Application.get_env(:circuit1b, :max_cadence_ms)
  defp leds, do: Application.get_env(:circuit1b, :leds)


end
