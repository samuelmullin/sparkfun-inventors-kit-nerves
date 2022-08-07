defmodule Circuit4b.Thermometer do
  use GenServer

  require Logger
  alias Circuits.I2C

  @adc_gain Application.get_env(:circuit4b, :adc_gain)
  @ads1115_address Application.get_env(:circuit4b, :ads1115_address)
  @thermometer_input Application.get_env(:circuit4b, :thermometer_input)

  # Per datasheet, TMP36 has an offset of 0.5v
  @tmp36_offset 0.5

  # Voltage range of sensor (0-2v) / ADC resolution (2^15 steps)
  @reading_to_voltage_multiplier 2.048 / 32768

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # --- Callbacks ---
  @impl true
  def init(_) do
    # Get our LCD config and start the LCD GenServer
    lcd_config = Application.fetch_env!(:circuit4b, :lcd_config)
    {:ok, lcd_ref} = LcdDisplay.HD44780.GPIO.start(lcd_config)

    # Open I2C-1 for input
    {:ok, ads_ref} = I2C.open("i2c-1")

    # Clear the screen
    LcdDisplay.HD44780.GPIO.execute(lcd_ref, :clear)

    Task.async(fn -> thermo_loop(ads_ref, lcd_ref) end)

    # Store our references in state so they don't get garbage collected
    {:ok, %{lcd_ref: lcd_ref}}
  end

  def thermo_loop(ads_ref, lcd_ref) do
    # It's possible to get a transient error - if we do, catch it and wait before our next reading.
    case ADS1115.read(ads_ref, @ads1115_address, {@thermometer_input, :gnd}, @adc_gain) do
      {:error, :i2c_nak} ->
        Logger.error("Error getting reading, skipping this reading.")
      {:ok, reading} ->
        Logger.info("reading: #{inspect(reading)}")

        reading = (reading * @reading_to_voltage_multiplier - @tmp36_offset) * 100

        reading =
          reading
          |> Float.round(1)
          |> Float.to_string()

        # Reset cursor to
        LcdDisplay.HD44780.GPIO.execute(lcd_ref, {:set_cursor, 0, 0})
        LcdDisplay.HD44780.GPIO.execute(lcd_ref, {:print, "Temp: #{reading}c"})
    end
    :timer.sleep(1000)
    thermo_loop(ads_ref, lcd_ref)
  end

end
