defmodule Circuit1c.Photoresistor do
  use GenServer

  require Logger
  alias Circuits.I2C
  alias Circuits.GPIO

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # --- Public API ---
  @doc"""
    Get the current reading from the photoresistor
  """
  def get_reading() do
    GenServer.call(__MODULE__, :get_reading)
  end

  @doc"""
    Get the current minimum threshold for turning on the LED
  """
  def get_threshold() do
    GenServer.call(__MODULE__, :get_threshold)
  end

  @doc"""
    Set a new minimum threshold for turning on the LED
  """
  def set_threshold(threshold) when is_integer(threshold) do
    GenServer.call(__MODULE__, {:set_threshold, threshold})
  end
  def set_threshold(threshold), do: {:error, :invalid_integer}

  # --- Callbacks ---

  @impl true
  def init(_) do
    # Open LED GPIO for output
    {:ok, led_gpio} = GPIO.open(led_pin(), :output)

    # Open I2C-1 for input
    {:ok, ads_ref} = I2C.open("i2c-1")

    # Kick off recursive task to blink our LED
    Task.async(fn -> light_loop(led_gpio) end)

    # Store our references in state so they don't get garbage collected
    {:ok, %{ads_ref: ads_ref, output_gpio: led_gpio, threshold: default_threshold()}}
  end

  @impl true
  def handle_call(:get_reading, _from, %{ads_ref: ads_ref} = state) do
    # Get a reading from our potentiometer
    {:ok, reading} = ADS1115.read(ads_ref, adc1115_address(), {:ain0, :gnd}, adc_gain())
    {:reply, reading, state}
  end

  @impl true
  def handle_call(:get_threshold, _from, %{threshold: threshold} = state) do
    {:reply, threshold, state}
  end

  @impl true
  def handle_call({:set_threshold, threshold}, _from, state) do
    {:reply, :ok, Map.put(state, :threshold, threshold)}
  end

  # Private Implementation

  defp light_loop(led_gpio) do
    threshold = get_threshold()
    reading = get_reading()
    light_led(reading, threshold, led_gpio)
    light_loop(led_gpio)
  end

  defp light_led(reading, threshold, led_gpio) when reading <= threshold, do: GPIO.write(led_gpio, 1)
  defp light_led(_, _, led_gpio), do: GPIO.write(led_gpio, 0)

  defp adc1115_address(), do: Application.get_env(:circuit1c, :adc1115_address)
  defp default_threshold(), do: Application.get_env(:circuit1c, :default_threshold)
  defp adc_gain, do: Application.get_env(:circuit1c, :adc_gain)
  defp led_gpio(), do: Application.get_env(:circuit1c, :led_gpio)

end
