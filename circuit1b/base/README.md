# Circuit 1B

## Overview

This circuit blinks an LED at a cadence determined by a value read from a potentiometer.

## Usage

After [creating and uploading the firmware](../../FIRMWARE.md), and after a startup time of 30s or so, the LED should blink at a cadence of 500ms.

If the LED does not blink as expected, refer to the [Troubleshooting Guide](../../TROUBLESHOOTING.md)

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

Plug the potentioometer into the breadboard on the left hand side.  Make sure to plug it in vertically - across a number of rows - not horizontally. 

Plug the ADS1115 module into the breadboard on the right hand side.  Make sure to plug it in vertically - across a number of rows - not horizontally.  Connect the vdd pin to the power rail on the right hand side.  Connect the gnd pin to the ground rail on the right hand side.  Connect the SCL pin to GPIO 3 on your raspberry pi.  Connect the SDA pin to GPIO 2 on your raspberry pi.  Connect the a0 pin to the middle pin of the potentiometer.

Finally, connect the topmost pin of your potentiometer to the power rail on the right hand side, and the bottommost pin to the ground rail on the right hand side.

## Application Definition & Dependencies

Our [application](./mix.exs) simply starts the Circuit1b module.

We have two non-standard dependencies for this project:

[ads1115](https://hexdocs.pm/ads1115/readme.html) which allows for control of our ADS1115 analog to digital converter
[circuits_gpio](https://hexdocs.pm/circuits_gpio/Circuits.GPIO.html) which allows for reading and writing to the GPIO pins on the raspberry pi

## Config

The [config](./config/config.exs) for Circuit1b defines the following:

`led_gpio: 26` - The GPIO pin used to control the LED
`max_reading: 27235` - The max value we expect to receive from our potentiometer.  This may vary and it can be adjusted up or down if things are not behaving as expected
`adc1115_address: 72` - The default for the ADS1115, but since it can be changed it is not hard coded.


## Supervision

The [supervisor](./lib/supervisor.ex) starts a single child process (Circuit1b.Potentiometer), and it specifies a `:one_for_one` strategy, which means if the child process dies, the supervisor will start a new one. 

## Application Logic

The application logic for this circuit is contained in the [Circuit1b.Potentiometer module](./lib/potentiometer.ex).

```elixir
defmodule Circuit1b.Potentiometer do
  use GenServer

  require Logger
  alias Circuits.I2C
  alias Circuits.GPIO

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end
```

In addition to Circuits.GPIO, which was used in Circuit1a, Circuit1b includes Circuits.I2C for interfacing with the ADS1115.

```elixir
   # --- Public API ---

  def get_reading() do
    GenServer.call(__MODULE__, :get_reading)
  end
```

A single public API setting is exposed, allowing the user to query the current reading for the potentiometer.  This can be used to adjust the max_reading value.  Adjust it upward if the max value is hit too soon when you twist the potentiometer.

```elixir

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
```

`init/1` Opens the LED GPIO and the I2C bus and then uses [Task.async/1]() to kick off a background process that begins blinking the LED by calling `blink_led/1` (which will be discussed further in the private implementation).  `Task.async/1` starts a linked and monitored process that executes asyncronously.  In normal use, it would be very important to clean up the task when finished (using await, yield or shutdown).  Since in this case it's an infinite loop, it's less important.

After kicking off the blink_led loop, the references are stored in state.

```elixir
# --- Private Implementation ---

  defp blink_led(led_gpio) do
    # Get the reading and convert to a whole number between 0 and 1000
    reading = get_reading()
    blink_ms = round((reading / max_reading()) * 1000) + 50

    # Turn the led on and sleep
    GPIO.write(led_gpio, 1)
    Process.sleep(blink_ms)

    # Turn the LED off and sleep
    GPIO.write(led_gpio, 0)
    Process.sleep(blink_ms)

    # Start over
    blink_led(led_gpio)
  end

```
`blink_led/1` uses the public api (`get_reading/0`) to get a reading from the potentiometer, and then converts that to a value (`blink_ms`) between 50 and 1050 ms.  The led is then turned on, then the process sleeps for `blink_ms`, after which the led is turned off and the process sleeps for another `blink_ms`.  After the second sleep, the function calls itself.

```elixir
  defp adc1115_address, do: Application.get_env(:circuit1b, :adc1115_address)
  defp max_reading, do: Application.get_env(:circuit1b, :max_reading)
  defp led_gpio, do: Application.get_env(:circuit1b, :led_gpio)
```

Finally we have some convenience functions to extract our config.
