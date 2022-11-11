# Circuit 1D

## Overview

This circuit changes the colour of an RGB LED based on the amount of light detected by a photoresistor.

## Usage

After [creating and uploading the firmware](../../FIRMWARE.md), and after a startup time of 30s or so, you should be able to change the colour of the LED by covering the photoresistor.

If the LED does not change colour as expected, try moving to a darker room or adjusting the default_threshold in the configuration (or by using `set_threshold/1` from the shell).  If it still doesn't work, refer to the [Troubleshooting Guide](../../TROUBLESHOOTING.md)

## Hardware

In order to complete this circuit, you'll need the following:

- 1 x Breadboard
- 1 x RGB LED
- 3 x 330ohm Resistor
- 7 x M-F Jumper cables
- 6 x M-M Jumper cables
- 1 x Analog Potentiometer
- 1 x Analog Photoresistor
- 1 x ADC1115 Analog-to-Digital Converter

## Wiring

In this circuit we are going to use both the 3.3v and 5v rails of the Raspberry pi, so pay attention to which to use in each case.  Connect a ground from the pi to the ground rails on each side of the breadobard, and connect the 3.3v to the left side and the 5v to the right side.

First let's plug the potentiometer into the breadboard.  We're going to use it to adjust the contrast of the LCD, so connect the topmost pin to the 5v rail and the bottommost pin to the ground rail.  We'll plug the middle pin into the LCD in a moment.

Plug the LCD screen into the breadboard.  The pins are located on the top-left corner of the LCD module, whichever direction you connect it, you are going to count the pins starting at 1 from that top left pin.  There are 16 pins in total, so let's connect them from top to bottom.

1) Connect to the ground rail
2) Connect to the 5v rail
3) Connect to the middle pin of the potentiometer
4) Connect to GPIO 21
5) Connect to the ground rail
6) Connect to GPIO 16
7) Unused
8) Unused
9) Unused
10) Unused
11) Connect to GPIO 22
12) Connect to GPIO 23
13) Connect to GPIO 24
14) Connect to GPIO 25
15) Connect to 5v rail
16) Connect to Ground rail


Next, we'll connect the ADS1115 and the TMP36 Sensor.

Plug the ADS1115 module into the breadboard. Make sure to plug it in vertically - across a number of rows - not horizontally.  Connect the vdd pin to the 3.3v rail.  Connect the gnd pin to the ground rail.  Connect the SCL pin to GPIO 3 on your raspberry pi.  Connect the SDA pin to GPIO 2 on your raspberry pi.

Finally, plug the TMP36 sensor into the breadboard.  Plug the 3.3v rail into the topmost pin and the ground rail into the bottommost pin.  Connect the middle pin to a0 on the ADS1115.


## Application Definition & Dependencies

Our [application](./mix.exs) simply starts the Circuit4b module.

We have three non-standard dependencies for this project:

[ads1115](https://hexdocs.pm/ads1115/readme.html) which allows for control of our ADS1115 analog to digital converter
[lcd_display](https://hexdocs.pm/lcd_display/readme.html) which allows for control of our HD44780 display

## Config

The [config](./config/config.exs) for Circuit4b defines the following:

```elixir
config :circuit4b,
  lcd_config: %{
    pin_rs: 21,
    pin_en: 16,
    pin_d4: 22,
    pin_d5: 23,
    pin_d6: 24,
    pin_d7: 25
  },
``` 

This is the config for the GPIO pins we'll use to control the LCD

```elixir
  ads1115_address: 72,
  adc_gain: 4096,
  thermometer_input: :ain0
```

This is the config we'll use to read the temperature of the TMP36 via the ADS1115


## Supervision

The [supervisor](./lib/supervisor.ex) starts a single child process (Circuit4b.Thermometer), and it specifies a `:one_for_one` strategy, which means if the child process dies, the supervisor will start a new one. 

## Application Logic

The application logic for this circuit is contained in the [Circuit4b.Thermometer Module](./lib/thermometer.ex).

```elixir
defmodule Circuit4b.Thermometer do
  use GenServer

  require Logger
  alias Circuits.I2C

  @adc_gain Application.compile_env!(:circuit4b, :adc_gain)
  @ads1115_address Application.compile_env!(:circuit4b, :ads1115_address)
  @thermometer_input Application.compile_env!(:circuit4b, :thermometer_input)

  # Per datasheet, TMP36 has an offset of 0.5v
  @tmp36_offset 0.5

  # Voltage range of sensor (0-4.096v) / ADC resolution (2^15 steps)
  @reading_to_voltage_multiplier 4.096 / 32768

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end
```

This block defines our module attributes, which include some config values, formulas and constants, as well as our start_link function.

```elixir
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
    {:ok, %{lcd_ref: lcd_ref, ads_ref: ads_ref}}
  end
```

Our init starts the LCD process, opens an I2C connection to the ADS1115 and kicks off our thermo-loop which will control the LCD using the output from the themometer.

```elixir
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
```

Our thermo-loop reads the temperature from the TMP36 (via the ADS1115), converts that value to a celcius value with a precision of 1, then prints that value to the screen.  It then sleeps for 1 second before calling itself again.