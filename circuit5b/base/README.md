# Circuit 5b - Remote operated robot

## Overview

This circuit is a remote operated robot that cna be controlled by running commands in the Nerves SSH shell.

## Usage

After [creating and uploading the firmware](../../FIRMWARE.md), and after a startup time of 30s or so, you should be able to drive the robot by sending it commands such as:

`Circuit5b.Drive.command(:forward, 3000)`, which will drive the robot forward for 3000ms.

If it doesn't turn as expected, check you wiring, paying close attention to the difference between the input (AI) and output (AO) sets of pins, and if it still doesn't work, refer to the [Troubleshooting Guide](../../TROUBLESHOOTING.md).

## Hardware

In order to complete this circuit, you'll need the following:

- 1 x Breadboard
- 1 x TB6612FNG Motor Driver
- 1 x DG01D Motor (+ Wheel)
- 1 x External Battery Pack
- 1 x SPST (or SPDT) switch
- 9 x M-F Jumper cables
- 5 x M-M Jumper cables

## Wiring

Start by connecting the 3.3v rail on the raspberry pi to the power rail on the right side of your breadboard and the ground on the raspberry pi to the ground rail on the left hand side of the breadboard.

Next connect the switch, plugging it into the breadboard, then connecting the bottom-most pin to GPIO 4 and the pin next to it to the ground rail.  If you are using a SPDT switch (three pins), you won't be using the last pin.

Next plug the TB22FNG Motor driver into the breadboard bridging the left and right sides.  Connect each ground pin into the ground rail (there are 3) and connect the pin marked VCC to the 3.3v rail.  Connect AI1 to GPIO 20, AI2 to GPIO 16, and PWM A to GPIO 12.  Connect B01 to GPIO 5, B02 to GPIO 6, and PWM B to GPIO 13.  Connect AO1 to the positive wire of the first motor, AO2 to the negative wire of the first motor, BO1 to the positive wire of the second motor and B02 to the negative wire of the second motor. Connnect STBY to GPIO 21.  Finally, connect the positive wire from the battery pack to the pin marked VM, and the negative wire from the battery pack to the ground rail.

## Application Definition & Dependencies

Our [application](./mix.exs) simply starts the Circuit5b module.

We have two non-standard dependencies for this project:

[circuits_gpio](https://hexdocs.pm/circuits_gpio/Circuits.GPIO.html) which allows for reading and writing to the GPIO pins on the raspberry pi
[:pigpiox](https://hexdocs.pm/pigpiox/Pigpiox.html) which allows us to use PWM with our GPIOs

## Config

The [config](./config/config.exs) for Circuit5b defines the following:

`switch_pin: 4` - The GPIO we're connecting to the on/off switch

```elixir
  tb6612_config: [
    standby_pin: 21,
    motor_a: [
      pwm_pin: 12,
      in01_pin: 20,
      in02_pin: 16,
      name: :motor_a
    ],
    motor_b: [
      pwm_pin: 13,
      in01_pin: 5,
      in02_pin: 6,
      name: :motor_b
    ]
  ]
``` - The config for the TB6612, including the standby pin used for the module, and the pins for the two motors we're using for this example.

## Supervision

The [supervisor](./lib/supervisor.ex) starts a single child process (Circuit5b.Drive), and it specifies a `:one_for_one` strategy, which means if the child process dies, the supervisor will start a new one. 

## Application Logic

The application logic for this circuit is contained in the [Circuit5b.Drive module](./lib/drive.ex).

```elixir
defmodule Circuit5b.Drive do
  use GenServer

  alias Circuits.GPIO
  alias TB6612FNG.Module

  @default_speed 250_000
  @directions [:forward, :backward, :left, :right]

```

Some aliases and module attributes to get things started

```elixir
  # --- Public API ---

  def set_speed(speed) when speed >= 0 and speed <= 1_000_000 do
    GenServer.cast(__MODULE__, {:set_speed, speed})
    {:ok, speed}
  end

  def set_speed(_) do
    {:error, "Speed must be between 0 and 1_000_000"}
  end

  def command(direction, time) when direction in @directions and is_integer(time) do
    GenServer.cast(__MODULE__, {:drive, :direction, :time})
  end

  def command(direction, _) do
    {:error, "Invalid direction: #{direction}.  Direction must be one of: #{inspect(directions)}"}

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

```

The public API allows the user to set the speed of the robot (which defaults to 250_000) and send commands to the robot, which indicate a direction and an amount of time.  The robot will then execute the commands in the order they are sent.

```elixir
  # --- Callbacks ---
  @impl true
  def init(_) do
    switch_pin = Application.get_env(:circuit5b, :switch_pin)
    tb6612_config = Application.fetch_env!(:circuit5b, :tb6612_config)

    {:ok, switch_ref} = GPIO.open(switch_pin, :input)
    GPIO.set_interrupts(switch_ref, :both)

    state = %{
      switch_ref: switch_ref,
      motor_a_name: get_in(tb6612_config, [:motor_a, :name]),
      motor_b_name: get_in(tb6612_config, [:motor_b, :name]),
      speed: @default_speed,
      enabled: false
    }

    {:ok, state}
  end
```

The init sets interrupts for switch so we know if the motors are enabled or disabled and also gets the names for the motors so we can use them when sending commands.

```elixir
  @impl true
  def handle_cast({:set_speed, speed}, state) do
    {:noreply, Map.put(state, :speed, speed)}
  end
```

This message adjusts the speed of the motors

```elixir
  @impl true
  def handle_cast({:drive, _, _}, %{enabled: false} = state) do
    Logger.info("Received drive but motors are disabled")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:drive, :forward, time}, %{speed: speed} = state) do
    Module.set_output(state.motor_a_name, :cw, speed)
    Module.set_output(state.motor_b_name, :cw, speed)
    Process.sleep(time)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:drive, :backward, time}, %{speed: speed} = state) do
    Module.set_output(state.motor_a_name, :ccw, speed)
    Module.set_output(state.motor_b_name, :ccw, speed)
    Process.sleep(time)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:drive, :right, time}, %{speed: speed} = state) do
    Module.set_output(state.motor_a_name, :cw, speed)
    Module.set_output(state.motor_b_name, :ccw, speed)
    Process.sleep(time)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:drive, :left, time}, %{speed: speed} = state) do
    Module.set_output(state.motor_a_name, :ccw, speed)
    Module.set_output(state.motor_b_name, :cw, speed)
    Process.sleep(time)
    {:noreply, state}
  end

```

These messages indicate commands the robot will follow - if the motors are disabled, nothing happens, otherwise the motor activates the two motors in order to activate the command.  A sleep inside the command ensures we don't begin processing the next command until the current one is complete.

```elixir
  @impl true
  def handle_info({:circuits_gpio, _, _, 1}, state) do
    {:noreply, Map.put(state, :enabled, true)}
  end

  @impl true
  def handle_info({:circuits_gpio, _, _, 0}, state) do
    {:noreply, Map.put(state, :enabled, false)}
  end

end
```

These messages toggle the 'enabled' state - commands will be ignored if the robot is not enabled. 
