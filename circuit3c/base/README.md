# Circuit 1D

## Overview

This circuit uses an Ultrasonic distance sensor to trigger a servo, RGB LED and piezo buzzer as part of a proximity alarm.

## Usage

After [creating and uploading the firmware](../../FIRMWARE.md), and after a startup time of 30s or so, you should be able to trigger the proximity alarm by moving your hand close to the ultrasonic distance sensor.  As you move your hand further away, you should be able to figure out the minimum distance you are required to stay away to avoid trigger it.

If it doesn't work, check the logs for errors from the Ultrasonic distance sensor - if any of the wires are not corrected properly, it's likely that you'll see a `-2` error code indicating a timeout.  If you can't find any errors and things still aren't working, refer to the [Troubleshooting Guide](../../TROUBLESHOOTING.md)

## Hardware

In order to complete this circuit, you'll need the following:

- 1 x Breadboard
- 9 x M-F Jumper cables
- 4 x M-M Jumper cables
- 1 x RGB LED
- 4 x 330ohm Resistor
- 1 x 470ohm Resistor
- 1 x HC-SR04 Ultrasonic Distance Sensor
- 1 x Micro Servo
- 1 x Piezo buzzer
  
## Wiring

There's a lot going on here, so let's break this up:

### Breadboard

Connect a ground pin to the ground rail on the left side of the breadboard.

### Piezo Buzzer

Connect the negative side of the Piezo buzzer to the ground rail of the breadboard, and then connect the positive side to GPIO 13, which is one of the hardware PWM pins.

### RGB LED

The RGB Led has a common annode - this means that three of the legs are positive (one for each colour) and one is negative.  We're going to bridge the right and left sides of our breadboard with 330ohm resistors for the three cathode legs of our led and then plug in the led.  On the right side of the breadboard, we're going to connect three GPIOs: 23, 24, 25.  Note that these are not PWM pins, we're just using normal GPIOs to run the RGB LED this time.  Then we'll connect the annode leg of the LED to the ground rail on the left side of the bread board.

### HC-SR04 Ultrasonic Sensor

Plug the HC-SR04 into the breadboard on the right hand side, spanning four rows (not across a single row).

The HC-SR04 has four pins: VCC, Trigger, Echo and Ground.  VCC can be connected directly to the 5v rail on the raspberry pi, Trigger can be connected to GPIO 22 and Ground can be connected to the ground rail on the left side of the breadboard.

Because the HC-SR04 uses 5v logic, we need to use a voltage divider to connect it to our Raspberry Pi.  Use a 330ohm resistor to bridge the left and right side of the breadboard in the same row as the Trigger pin, then use a 470ohm resistor on the left side to connect that row to the ground rail.  Connect GPIO 27 to the breadboard on the left side between the resistors.  This will ensure that GPIO 27 only receives a 3.3v signal, and prevents us from damaging it.


### Microservo

The Microservo requires a PWM signal, but also needs more power than our Raspberry pi wants to provide.  As a result, we'll need to hook our battery pack up to the breadboard to give it ~5v.  Plug it into the breadboard across 3 unused rows at the bottom of the right hand side, then plug the battery pack 5v power out into the same row as the red wire, the battery pack ground onto the ground rail of the raspberry pi, connect the row with the black wire to the ground rail as well, and connect the row with the white wire to GPIO 12.

Optional:  Add an arm to the microservo using a paperclip and tape something funny to it.  Arrange the microservo so that when looking at it from the front, you cannot see the attachment, but when it is triggered, it will swing towards you and show it off.


## Application Definition & Dependencies

Our [application](./mix.exs) simply starts the [Circuit3c](./lib/circuit3c.ex) module.

We have three non-standard dependencies for this project:

[:nerves_hcsr04](https://www.github.com/samuelmullin/nerves_hcsr04) (a fork updated to work with a  newer version of Elixir/Nerves) which allows for measuring distance using the HC-SR04 ultrasonic distance sensor using an Elixir Port. 

[:pigpiox](https://hexdocs.pm/pigpiox/Pigpiox.html) which allows us to use PWM with our GPIOs

[:circuits_gpio](https://hexdocs.pm/circuits_gpio/Circuits.GPIO.html) which allows for reading and writing to the GPIO pins on the raspberry pi

## Config

The [config](./config/config.exs) for Circuit1b defines the following:

config :circuit3c,
```elixir
  led_gpios: %{
    red: 23,
    green: 24,
    blue: 25
  },
``` - The GPIO pin config for our RGB LED

```elixir
  hcsr04: %{
    trigger: 22,
    echo: 27
  },
``` - The GPIO pin config for our HC-SR04 Ultrasonic sensor

```elixir
  servo_gpio: 12,
  servo_range: {800, 2200},
  buzzer_gpio: 13
``` - The GPIO pin config for our servo and buzzer, along with the defined range for our servo.


## Supervision

The [supervisor](./lib/supervisor.ex) starts a single child process (Circuit3c.Alarm), and it specifies a `:one_for_one` strategy, which means if the child process dies, the supervisor will start a new one. 

## Application Logic

The application logic for this circuit is contained in the [Circuit3c.Alarm module](./lib/alarm.ex).

```elixir
defmodule Circuit3c.Alarm do
  use GenServer

  require Logger
  alias Circuit3c.HCSR04
  alias Circuits.GPIO

  @buzzer_gpio       Application.compile_env!(:circuit3c, :buzzer_gpio)
  @led_gpios         Application.compile_env!(:circuit3c, :led_gpios)
  @servo_gpio        Application.compile_env!(:circuit3c, :servo_gpio)
  @servo_range       Application.compile_env!(:circuit3c, :servo_range)
  @hcrs04            Application.compile_env!(:circuit3c, :hcrs04)

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end
```

First we define all our module attributes and our start_link function.

```elixir

  # --- Callbacks ---
  @impl true
  def init(_) do
    # Get our HCSR04 config and start the HCSR04 GenServer
    hcsr04_config = Application.fetch_env!(:circuit3c, :hcsr04)
    {:ok, hcsr04_ref} = HCSR04.start_link({hcsr04_config.echo, hcsr04_config.trigger})

    # Open LED GPIOs and store references
    {:ok, red_ref} = GPIO.open(@led_gpios.red, :output)
    {:ok, green_ref} = GPIO.open(@led_gpios.green, :output)
    {:ok, blue_ref} = GPIO.open(@led_gpios.blue, :output)

    state = %{
      red_ref: red_ref,
      green_ref: green_ref,
      blue_ref: blue_ref,
      hcsr04_ref: hcsr04_ref
    }

    # Kick off recursive task to light our LED
    Task.async(fn -> alarm_loop(state) end)

    # Store our references in state so they don't get garbage collected
    {:ok, state}
  end
```

Our only callback is `init/1`, which kicks off our HC-SR04 server, opens references for our LED GPIOs and kicks off the alarm loop.

```elixir
  # Private Implementation
  defp alarm_loop(refs) do
    with :ok             <- HCSR04.update(refs.hcsr04_ref),
         {:ok, distance} <- HCSR04.info(refs.hcsr04_ref)
      do
        check_alarm(distance, refs)
      else
        {:error, code} ->
          Logger.error("Error received when obtaining HCSR04 Reading: #{code}")
      end
    :timer.sleep(100)
    alarm_loop(refs)
  end

  # <25 CM, Light LED Red, Servo to Max, Buzzer
  defp check_alarm(distance, refs) when distance < 10 do
    {_servo_min, servo_max} = @servo_range
    GPIO.write(refs.red_ref, 1)
    GPIO.write(refs.green_ref, 0)
    GPIO.write(refs.blue_ref, 0)
    Pigpiox.Pwm.hardware_pwm(@buzzer_gpio, 800, 500_000)
    Pigpiox.GPIO.set_servo_pulsewidth(@servo_gpio, servo_max)
  end
  # <50cm, Light LED Yellow
  defp check_alarm(distance, refs) when distance < 50 do
    {servo_min, _servo_max} = @servo_range
    GPIO.write(refs.red_ref,  1)
    GPIO.write(refs.green_ref,1)
    GPIO.write(refs.blue_ref, 0)
    Pigpiox.Pwm.hardware_pwm(@buzzer_gpio, 0, 0)
    Pigpiox.GPIO.set_servo_pulsewidth(@servo_gpio, servo_min)

  end
  # >50cm, Light LED Green
  defp check_alarm(_distance, refs) do
    {servo_min, _servo_max} = @servo_range
    GPIO.write(refs.red_ref, 0)
    GPIO.write(refs.green_ref, 1)
    GPIO.write(refs.blue_ref, 0)
    Pigpiox.Pwm.hardware_pwm(@buzzer_gpio, 0, 0)
    Pigpiox.GPIO.set_servo_pulsewidth(@servo_gpio, servo_min)
  end
end
```

Our private implementation defines two functions:

`alarm_loop/1` - Gets an updated reading from our HC-SR04 and calls `check_alarm/2`
`check_alarm/2` - Uses the reading from alarm loop to determine what to do with the Servo, LED and Buzzer.  If the object is 25cm or closer, the servo swings forward, the buzzer sounds and the LED turns red.  Otherwise, the LED just turns yellow or green depending on the distance.