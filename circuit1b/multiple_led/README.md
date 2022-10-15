# Circuit 1B

## Overview

For this challenge, the GenServer is extended to allow for customization of the blink interval.  This includes exposing a public API that allows the user to update a value in the state of the GenServer.  That value is used instead of the module attribute the original circuit used.  There are no changes to the hardware of the circuit.

## Usage

Additional LEDs can be added by modifying the `leds` list in the [config](./config/config.ex).

After [creating and uploading the firmware](../../FIRMWARE.md), the LEDs should begin to blink at different cadences.  Turning the potentiometer will cause them to speed up or slow down accordingly.

If the LEDs do not blink as expected, refer to the [Troubleshooting Guide](../../TROUBLESHOOTING.md)

## Hardware

In addition to the hardware  from the [base circuit](../base/README.md#hardware), this circuit uses:

- 2 LEDs of any colour
- 2 330ohm resistors
- 2 M-F jumper cables

## Wiring

In addition to the to the wiring from the [base circuit](../base/README.md#wiring), make the following connections

- One LED connected to GPIO 19, connected in the same fashion as the LED from the original circuit
- One LED connected to GPIO 13, connected in the same fashion as the LED from the original circuit

## Application Definition & Dependencies

There are no changs to the Application Definiton & Dependencies from the [base circuit](../base/README.md#application-definition--dependencies)

## Config

The [config](./config/config.exs) for this version of the circuit was updated to contain a list of LEDs, including their GPIO and the multiplier that should be applied to their blink cadence (to speed it up or slow it down relative to the other LEDs) and a `max_cadence_ms` value that defaults to 1000.

```Elixir
config :circuit1b,
  leds: [
    %{gpio: 26, cadence_multiplier: 1},
    %{gpio: 19, cadence_multiplier: 2},
    %{gpio: 13, cadence_multiplier: 0.5},
  ],
  max_reading: 27235,
  adc1115_address: 72,
  adc_gain: 4096,
  max_cadence_ms: 1000
```


## Supervision

There are no changes to the Supervision from the [base circuit](../base/README.md#supervision)


## Application Logic

The primary change made is to start one async process for every LED, instead of a single process.

```elixir
    # Open each LED GPIO for output
    leds = Enum.map(leds(), fn led ->
      {:ok, output_gpio} = GPIO.open(led[:gpio], :output)
      Map.put(led, :output_gpio, output_gpio)
    end)
```

First the GPIO for each LED is opened for output and stored in the LED list.

```elixir
# Kick off recursive task to blink our LED
    Enum.each(leds, fn led -> Task.async(fn -> blink_led(led) end) end)
```

Then an async task is kicked off for each of the leds in the list.

```elixir
blink_ms = round((((reading / max_reading()) * max_candence_ms()) + 50) * led[:cadence_multiplier])
```

In the private implementation, there's also a new max_cadence_ms() function that pulls a value out of the config to determine the maximum cadence the circuit will use for LED blinks.  Previously it was hard-coded to 1000.

