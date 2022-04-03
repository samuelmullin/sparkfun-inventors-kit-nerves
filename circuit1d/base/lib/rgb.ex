defmodule Circuit1d.RGB do
  use GenServer

  require Logger
  alias Circuits.I2C

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # --- Public API ---

  @doc"""
    Get the current reading from the photoresistor
  """
  def get_photoresistor_reading() do
    GenServer.call(__MODULE__, :photoresistor_reading)
  end

  @doc"""
    Get the current reading from the potentiometer
  """
  def get_potentiometer_reading() do
    GenServer.call(__MODULE__, :potentiometer_reading)
  end

  @doc"""
    Get the current minimum threshold for turning on the LED
  """
  def get_threshold() do
    GenServer.call(__MODULE__, :get_threshold)
  end

  @doc"""
    Get the current minimum threshold for turning on the LED
  """
  def set_threshold(value) when is_integer(value) do
    GenServer.call(__MODULE__, {:set_threshold, value})
  end
  def set_threshold(_value), do: {:error, :invalid_integer}


  # --- Callbacks ---

  @impl true
  def init(_) do
    # Open I2C-1 for input
    {:ok, ads_ref} = I2C.open("i2c-1")

    # Kick off recursive task to blink our LED
    Task.async(fn -> light_loop(ads_ref) end)

    # Store our references in state so they don't get garbage collected
    {:ok, %{ads_ref: ads_ref, threshold: default_threshold()}}
  end

  @impl true
  def handle_call(:photoresistor_reading, _from, %{ads_ref: ads_ref} = state) do
    {:ok, reading} = get_reading(ads_ref, :photoresistor)
    {:reply, reading, state}
  end

  @impl true
  def handle_call(:potentiometer_reading, _from, %{ads_ref: ads_ref} = state) do
    {:ok, reading} = get_reading(ads_ref, :potentiometer)
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

  defp light_loop(ads_ref) do
    threshold = get_threshold()
    {:ok, potentiometer_reading} = get_reading(ads_ref, :potentiometer)
    {:ok, photoresistor_reading} = get_reading(ads_ref, :photoresistor)

    over_threshold = photoresistor_reading <= threshold
    led_brightness = round((potentiometer_reading / potentiometer_max()) * 1_000_000) + 50

    light_led(over_threshold, led_brightness)
    light_loop(ads_ref)
  end

  defp light_led(true, led_brightness) do
    Pigpiox.Pwm.hardware_pwm(led_gpio(:green), 1000, led_brightness)
    Pigpiox.Pwm.hardware_pwm(led_gpio(:red), 0, 0)
    Pigpiox.Pwm.hardware_pwm(led_gpio(:blue), 0, 0)
  end
  defp light_led(false, led_brightness) do
    Pigpiox.Pwm.hardware_pwm(led_gpio(:green), 0, 0)
    Pigpiox.Pwm.hardware_pwm(led_gpio(:red), 1000, led_brightness)
    Pigpiox.Pwm.hardware_pwm(led_gpio(:blue), 0, 0)
  end

  defp get_reading(ads_ref, sensor) do
    analog_pin = sensor_analog_input(sensor)
    ADS1115.read(ads_ref, adc1115_address(), {analog_pin, :gnd}, adc_gain())
  end

  def sensor_analog_input(sensor), do: Application.get_env(:circuit1d, :analog_inputs) |> Map.get(sensor)
  defp adc1115_address(), do: Application.get_env(:circuit1d, :adc1115_address)
  defp default_threshold(), do: Application.get_env(:circuit1d, :default_threshold)
  defp potentiometer_max(), do: Application.get_env(:circuit1d, :potentiometer_max_reading)
  defp adc_gain, do: Application.get_env(:circuit1d, :adc_gain)
  defp led_gpio(colour), do: Application.get_env(:circuit1d, :led_gpios) |> Map.get(colour)

end
