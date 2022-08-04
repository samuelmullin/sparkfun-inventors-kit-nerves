defmodule Circuit3a.Servo do
  use GenServer

  require Logger
  alias Circuits.I2C

  @adc_gain          Application.get_env(:circuit3a, :adc_gain)
  @ads1115_address   Application.get_env(:circuit3a, :ads1115_address)
  @analog_inputs     Application.get_env(:circuit3a, :analog_inputs)
  @potentiometer_max Application.get_env(:circuit3a, :potentiometer_max_reading)
  @servo_gpio        Application.get_env(:circuit3a, :servo_gpio)
  @servo_range       Application.get_env(:circuit3a, :servo_range)

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # --- Callbacks ---
  @impl true
  def init(_) do
    {servo_min, servo_max} = @servo_range

    # Determine how far the servo should move when the potentiometer is moved
    servo_step = ((servo_max - servo_min) / @potentiometer_max)

     # Open I2C-1 for input
     {:ok, ads_ref} = I2C.open("i2c-1")

     # Kick off recursive task to blink our LED
     Task.async(fn -> servo_loop(ads_ref, servo_min, servo_step) end)

     # Store our references in state so they don't get garbage collected
     {:ok, %{ads_ref: ads_ref, servo_step: servo_step}}
  end

  # --- Private Implementation ---

  defp servo_loop(ads_ref, servo_min, servo_step) do
    # Get current potentiometer reading
    {:ok, potentiometer_reading} = get_reading(ads_ref, :potentiometer)

    # Determine servo position using reading
    new_servo_position = servo_min + round(potentiometer_reading * servo_step)

    # Move servo to desired position
    Pigpiox.GPIO.set_servo_pulsewidth(@servo_gpio, new_servo_position)

    # Do it again
    servo_loop(ads_ref, servo_min, servo_step)
  end

  defp get_reading(ads_ref, sensor) do
    sensor_address = Map.get(@analog_inputs, sensor)
    # It's possible to get a transient error - if we do, catch it and wait before our next reading.
    case ADS1115.read(ads_ref, @ads1115_address, {sensor_address, :gnd}, @adc_gain) do
      {:error, :i2c_nak} ->
        Logger.error("Error getting reading, sleeping 5ms")
        :timer.sleep(5)
         get_reading(ads_ref, sensor)
      {:ok, reading} ->
        Logger.info("reading: #{inspect(reading)}")
        {:ok, reading}
    end
  end

end
