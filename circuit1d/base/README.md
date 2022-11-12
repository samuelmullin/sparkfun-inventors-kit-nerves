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

Start by connecting the 5v rail on the raspberry pi to the power rail on the right side of your breadboard and the ground on the raspberry pi to the ground rail on the left hand side of the breadboard.

The RGB Led has a common annode - this means that three of the legs are positive (one for each colour) and one is negative.  We're going to bridge the right and left sides of our breadboard with 330ohm resistors for the three cathode legs of our led and then plug in the led.  On the right side of the breadboard, we're going to connect three GPIOs:  12, 13, 18.  These correspond to three of the four hardware PWM pins on the raspberry pi.  Then we'll connect the annode leg of the LED to the ground rail on the left side of the bread board.

Plug the ADS1115 module into the breadboard on the right hand side.  Make sure to plug it in vertically - across a number of rows - not horizontally.  Connect the vdd pin to the power rail on the right hand side.  Connect the gnd pin to the ground rail on the right hand side.  Connect the SCL pin to GPIO 3 on your raspberry pi.  Connect the SDA pin to GPIO 2 on your raspberry pi.

Plug the potentiometer into the breadboard on the left hand side.  Make sure to plug it in vertically - across a number of rows - not horizontally. Connect the a0 pin on the ADS1115 to the middle pin of the potentiometer.  Connect the power rail to the topmost pin and the ground rail to the bottommost pin.

Plug the photoresistor into the breadboard on the left hand side.  Make sure to plug it in vertically - across two rows, not horizontally.

Connect a jumper from the power rail to the row with the first leg of the photoresistor.  Connect a 10k ohm resistor from the row with the second leg of the photoresistor to the ground.  Connect the a1 pin from the ADS1115 to the same row as the second leg of the photoresistor.


## Application Definition & Dependencies

Our [application](./mix.exs) simply starts the Circuit1D module.

We have three non-standard dependencies for this project:

[ads1115](https://hexdocs.pm/ads1115/readme.html) which allows for control of our ADS1115 analog to digital converter
[circuits_gpio](https://hexdocs.pm/circuits_gpio/Circuits.GPIO.html) which allows for reading and writing to the GPIO pins on the raspberry pi
[:pigpiox](LINK GOES HERE) which allows us to use PWM with our GPIOs

## Config

The [config](./config/config.exs) for Circuit1D defines the following:

`default_threshold: 12000` - The threshold that will cause the LED to turn on.  If your room is particularly bright(lit by daylight), this may need to be greatly increased.  The value can also be changed while running by using `set_threshold/1`
`potentiometer_max_reading: 27375` - The max value we expect to receive from our potentiometer.  This may vary and it can be adjusted up or down if things are not behaving as expected
`adc1115_address: 72` - The default for the ADS1115, but since it can be changed it is not hard coded.
`adc_gain: 4096` - The amount of gain to apply to the value read - this impacts the full scale range.  Accepted values are: 6144, 4096, 2048, 1024, 512, 256.  Since the logic on the Raspberry Pi is 3.3v, we use 4096.

```elixir
analog_inputs: %{
  potentiometer: :ain0,
  photoresistor: :ain1
}
``` - Mappings from the analog input pins to the sensors we are using.

```elixir
led_gpios: %{
  red: 13,
  green: 18,
  blue: 12
}
``` - Mappings from the pins on the cathode pins on the RBG LED to GPIO pins on the Raspberry Pi.


## Supervision

The [supervisor](./lib/supervisor.ex) starts a single child process (Circuit1d.RGB), and it specifies a `:one_for_one` strategy, which means if the child process dies, the supervisor will start a new one. 

## Application Logic

The application logic for this circuit is contained in the [Circuit1d.RGB module](./lib/rgb.ex).

```elixir
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
```

Three functions are exposed via the public API, allowing the user to get the current readings, get the current threshold or set a new minimum threshold.  Like [Circuit1D](../../circuit1d/), `set_threshold/1` is particularly useful here as the minimum threshold required to turn on the light will vary greatly depending on the ambient lighting of the room.


```elixir
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
```

All the callbacks here should seem very similar to the callbacks implemented in [Circuit1b](../../circuit1b/) and [Circuit1c](../../circuit1c/).

```elixir
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
```

`light_loop/1` is called by our init function and will continue calling itself over and over.  It checks the readings from the potentiometer and photoresistor, checks if we're over the threshold to change the LED colour and adjusts the brightness of the LED.
