# Circuit 5a

## Overview

This circuit runs a DC motor using a motor driver.

## Usage

After [creating and uploading the firmware](../../FIRMWARE.md), and after a startup time of 30s or so, you should see the motor start turning when the switch is turned on, and you should see it stop when the switch is turned off.

If it doesn't turn as expected, check you wiring, paying close attention to the difference between the input (AI) and output (AO) sets of pins, and if it still doesn't work, refer to the [Troubleshooting Guide](../../TROUBLESHOOTING.md)

## Hardware

In order to complete this circuit, you'll need the following:

- 1 x Breadboard
- 1 x TB6612FNG Motor Driver
- 1 x DG01D Motor (+ Wheel)
- 1 x External Battery Pack
- 1 x SPST (or SPDT) switch
- 6 x M-F Jumper cables
- 5 x M-M Jumper cables

## Wiring

Start by connecting the 3.3v rail on the raspberry pi to the power rail on the right side of your breadboard and the ground on the raspberry pi to the ground rail on the left hand side of the breadboard.

Next connect the switch, plugging it into the breadboard, then connecting the bottom-most pin to GPIO 4 and the pin next to it to the ground rail.  If you are using a SPDT switch (three pins), you won't be using the last pin.

Next plug the TB22FNG Motor driver into the breadboard bridging the left and right sides.  Connect each ground pin into the ground rail and connect the pin marked VCC to the 3.3v rail.  Connect AI1 to GPIO 20, AI2 to GPIO 16, STBY to 21 and PWM A to GPIO 12.  Connect AO1 to the positive wire of the motor and AO2 to the negative wire of the motor.  Finally, connect the positive wire from the battery pack to the pin marked VM, and the negative wire from the battery pack to the ground rail.


## Application Definition & Dependencies

Our [application](./mix.exs) simply starts the Circuit5A module.

We have two non-standard dependencies for this project:

[circuits_gpio](https://hexdocs.pm/circuits_gpio/Circuits.GPIO.html) which allows for reading and writing to the GPIO pins on the raspberry pi
[:pigpiox](https://hexdocs.pm/pigpiox/Pigpiox.html) which allows us to use PWM with our GPIOs

## Config

The [config](./config/config.exs) for Circuit5a defines the following:

`switch_pin: 4` - The GPIO we're connecting to the on/off switch

```elixir
  tb6612_config: [
    standby_pin: 21,
    motor_a: [
      pwm_pin: 12,
      in01_pin: 20,
      in02_pin: 16,
      name: :tb6612fng_module_1_motor_a
    ],
    name: :tb6612fng_module_1
  ]
``` - The config for the TB6612, including the standby pin used for the module, and the pins for the one motor we're using for this example.

## Supervision

The [supervisor](./lib/supervisor.ex) starts a single child process (Circuit5a.Motor), and it specifies a `:one_for_one` strategy, which means if the child process dies, the supervisor will start a new one. 

## Application Logic

The application logic for this circuit is contained in the [Circuit5a.Motor module](./lib/motor.ex).

```elixir
 defmodule Circuit5a.Motor do
  use GenServer

  alias Circuits.GPIO
  alias TB6612FNG.Module
```
We alias Circuits.GPIO and TB6612FNG.Module for ease of use

```elixir
  # --- Callbacks ---
    @impl true
  def init(_) do
    switch_pin = Application.fetch_env!(:circuit5a, :switch_pin)
    motor_a_name = Application.fetch_env!(:circuit5a, :tb6612_config)
    |> get_in([:motor_a, :name])

    {:ok, switch_ref} = GPIO.open(switch_pin, :input)
    GPIO.set_interrupts(switch_ref, :both)

    {:ok, %{switch_ref: switch_ref, motor_a_name: motor_a_name, enabled: false, speed: @default_speed}}
  end
  ```

  The init opens the GPIO for the switch and sets interrupts so we know when it's state changes.  It also grabs the name of the motor process so we can interact with it.  Both of these are stored in the state.

```elixir
@impl true
  def handle_cast({:set_speed, speed}, %{enabled: true} = state) do
    Module.set_output(state.motor_a_name, :cw, speed)
    {:noreply, Map.put(state, :speed, speed)}
  end

  @impl true
  def handle_cast({:set_speed, speed}, %{enabled: false} = state) do
    {:noreply, Map.put(state, :speed, speed)}
  end
```

These messages adjust the speed of the motor.  If the motor is enabled it will change speeds, if it's not enabled it will just store the new speed for the next time it is enabled.


```elixir
  @impl true
  def handle_info({:circuits_gpio, _, _, 1}, %{speed: speed} = state) do
    Module.set_output(state.motor_a_name, :cw, speed)
    {:noreply, Map.put(state, :enabled, true)}
  end

  @impl true
  def handle_info({:circuits_gpio, _, _, 0}, state) do
    Module.set_output(state.motor_a_name, :cw, 0)
    {:noreply, state |> Map.put(:enabled, false)}
  end
```

The rest of our application logic says, if you see the switch go high, turn the motor at the given speed.  If you see it go low, turn the motor off.  Pretty simple, but we'll build on that in 5b and 5c.
