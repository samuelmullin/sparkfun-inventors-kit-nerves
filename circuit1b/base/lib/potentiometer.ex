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
    # Open LED GPIO for output
    {:ok, output_gpio} = GPIO.open(led_gpio(), :output)

    # Open I2C-1 for input
    {:ok, ads_ref} = I2C.open("i2c-1")

    # Kick off recursive task to blink our LED
    Task.async(fn -> blink_led(output_gpio) end)

    # Store our references in state so they don't get garbage collected
    {:ok, %{ads_ref: ads_ref, output_gpio: output_gpio}}
  end

  @impl true
  def handle_call(:get_reading, _from, %{ads_ref: ads_ref} = state) do
    # Get a reading from our potentiometer
    {:ok, reading} = ADS1115.read(ads_ref, adc1115_address(), {:ain0, :gnd}, 6144)
    {:reply, reading, state}
  end

  # --- Private Implementation ---

  defp blink_led(led_gpio) do
    # Get the reading and convert to a whole number between 0 and 1000
    reading = get_reading()
    speed = round((reading / max_reading()) * 1000)

    # Turn the led on and sleep
    GPIO.write(led_gpio, 1)
    Process.sleep(speed)

    # Turn the LED off and sleep
    GPIO.write(led_gpio, 0)
    Process.sleep(speed)

    # Start over
    blink_led(led_gpio)
  end

  defp adc1115_address, do: Application.get_env(:circuit1b, :adc1115_address)
  defp max_reading, do: Application.get_env(:circuit1b, :max_reading)
  defp led_gpio, do: Application.get_env(:circuit1b, :led_gpio)

end
