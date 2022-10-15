# Circuit 1C

## Overview

This circuit turns an LED on/off based on the amount of light detected by a photoresistor

## Usage

After [creating and uploading the firmware](../../FIRMWARE.md), and after a startup time of 30s or so, you should be able to turn on the LED by covering the photoresistor.

If the LED does not turn on as expected, try moving to a darker room or adjusting the default_threshold in the configuration (or by using `set_threshold/1` from the shell).  If it still doesn't work, refer to the [Troubleshooting Guide](../../TROUBLESHOOTING.md)

## Hardware

In order to complete this circuit, you'll need the following:

- 1 x Breadboard
- 1 x LED - Colour doesn't really matter here, but we don't want RGB
- 1 x 330ohm Resistor
- 5 x M-F Jumper cables
- 5 x M-M Jumper cables
- 1 x Analog Potentiometer
- 1 x ADC1115 Analog-to-Digital Converter

## Wiring

[Need a diagram or a picture here]

Bridge the left and right side of the breadboard with your LED.  The cathode should be on the right side.  Connect the left side of the breadboard to the ground rail on the left side of the breadboard.

Connect any ground on the raspberry pi to the ground rail on the right hand side.  Connect GPIO 26 to the same row as the cathode.

Connect the 5v rail of the raspberry pi to the power(+) rail on the right hand side. 

Plug the ADS1115 module into the breadboard on the right hand side.  Make sure to plug it in vertically - across a number of rows - not horizontally.  Connect the vdd pin to the power rail on the right hand side.  Connect the gnd pin to the ground rail on the right hand side.  Connect the SCL pin to GPIO 3 on your raspberry pi.  Connect the SDA pin to GPIO 2 on your raspberry pi.

Plug the photoresistor into the breadboard on the left hand side.  Make sure to plug it in vertically - across two rows, not horizontally.

Connect a jumper from the power rail to the row with the first leg of the photoresistor.  Connect a 10k ohm resistor from the row with the second leg of the photoresistor to the ground.  Connect the a0 pin from the ADS1115 to the same row as the second leg of the photoresistor.


## Application Definition & Dependencies

Our [application](./mix.exs) simply starts the Circuit1c module.

We have two non-standard dependencies for this project:

[ads1115](https://hexdocs.pm/ads1115/readme.html) which allows for control of our ADS1115 analog to digital converter
[circuits_gpio](https://hexdocs.pm/circuits_gpio/Circuits.GPIO.html) which allows for reading and writing to the GPIO pins on the raspberry pi

## Config

The [config](./config/config.exs) for Circuit1b defines the following:

`led_gpio: 26` - The GPIO pin used to control the LED
`default_threshold: 12000` - The threshold that will cause the LED to turn on.  If your room is particularly bright(lit by daylight), this may need to be greatly increased.  The value can also be set at runtime by using `set_threshold/1`
`adc1115_address: 72` - The default for the ADS1115, but since it can be changed it is not hard coded.
`adc_gain: 4096` - The amount of gain to apply to the value read - this impacts the full scale range.  Accepted values are: 6144, 4096, 2048, 1024, 512, 256.  Since the logic on the Raspberry Pi is 3.3v, we use 4096.

## Supervision

The [supervisor](./lib/supervisor.ex) starts a single child process (Circuit1c.Photoresistor), and it specifies a `:one_for_one` strategy, which means if the child process dies, the supervisor will start a new one. 

## Application Logic

The application logic for this circuit is contained in the [Circuit1c.Photoresistor module](./lib/photoresistor.ex).

```elixir
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
```

Three functions are exposed via the public API, allowing the user to get the current reading, get the current threshold or set a new minimum threshold.  `set_threshold/1` is particularly useful here as the minimum threshold required to turn on the light will vary greatly depending on the ambient lighting of the room.


```elixir
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
```
After initializing in a familiar pattern which kicks off an async loop, the message handlers corresponding to the public API endpoints are included.  This time around the messages are coming in as `call` instead of `info` or `cast`.  This means the responses are synchonous - the caller will wait for the GenServer to answer before continuing.

```elixir
defp light_loop(led_gpio) do
    light_led(reading(), threshold()) led_gpio)
    light_loop(led_gpio)
  end

  defp light_led(reading, threshold, led_gpio) when reading <= threshold, do: GPIO.write(led_gpio, 1)
  defp light_led(_, _, led_gpio), do: GPIO.write(led_gpio, 0)
```

The light loop simply calls `light_led/3` with the current reading and threshold and either turns off or turns off the led GPIO accordingly, then calls itself again.
