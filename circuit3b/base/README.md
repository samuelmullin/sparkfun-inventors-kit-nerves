# Circuit 3B

## Overview

This circuit changes the colour of an RGB LED based on the distance measured by an Ultrasonic distance sensors

## Usage

After [creating and uploading the firmware](../../FIRMWARE.md), and after a startup time of 30s or so, you should be able to change the colour of the LED moving your hand closer to or further from the Ultrasonic Sensor.

If the LED does not change colour as expected, try moving to a darker room or adjusting the default_threshold in the configuration (or by using `set_threshold/1` from the shell).  If it still doesn't work, refer to the [Troubleshooting Guide](../../TROUBLESHOOTING.md)

## Hardware

In order to complete this circuit, you'll need the following:

- 1 x Breadboard
- 1 x Common Annode RGB LED
- 4 x 330ohm Resistor
- 1 x 470ohm resistor
- 7 x M-F Jumper cables
- 2 x M-M Jumper cables
- 1 x HC-SR04 Ultrasonic Distance Sensor

## Wiring


Start by connecting the ground on the raspberry pi to the ground rail on the left hand side of the breadboard.

The RGB Led has a common annode - this means that three of the legs are positive (one for each colour) and one is negative.  We're going to bridge the right and left sides of our breadboard with 330ohm resistors for the three cathode legs of our led and then plug in the led.  On the right side of the breadboard, we're going to connect three GPIOs:  12, 13, 18.  These correspond to three of the four hardware PWM pins on the raspberry pi.  Then we'll connect the annode leg of the LED to the ground rail on the left side of the bread board.

Plug the HC-SR04 module into the Breadboard on the right side.  The HC-SR04 works on 5v logic and our Raspberry pi works on 3.3v, which means we'll need a voltage divider in order to step down the voltage to avoid damaging the GPIO pin on our PI.  First, connect GPIO 22 to the TRIGGER pin.  This is an output for the Pi so we are not concerned about the 5v voltage here.  We're going to use GPIO 27 for the echo pin, but instead of plugging it into the HC-SR04 directly, plug it in on the other side of the breadboard, then bridge the two sides of the breadboard using a 330ohm resistor.  Now, on the far side, use a 470ohm resistor to bridge that row to the ground, and then plug GPIO 27 in between the two resistors.  Finally, connect a 5v pin on the raspberry pi to the VCC on the HC-SR04, and the ground pin to the ground rail on the breadboard.



## Application Definition & Dependencies

Our [application](./mix.exs) simply starts the Circuit3b module.

We have two non-standard dependencies for this circuit:

[nerves_hcsr04](https://www.github.com/samuelmullin/nerves_hcsr04) (a fork updated to work with a  newer version of Elixir/Nerves) which allows for measuring distance using the HC-SR04 ultrasonic distance sensor using an Elixir Port. 

[:pigpiox](https://hexdocs.pm/pigpiox/Pigpiox.html) which allows us to use PWM with our GPIOs

## Config

The [config](./config/config.exs) for Circuit3b defines the following:


```elixir
led_gpios: %{
  red: 13,
  green: 18,
  blue: 12
}
``` - Mappings from the pins on the cathode pins on the RBG LED to GPIO pins on the Raspberry Pi.
```elixir
  hcsr04: %{
    trigger: 22,
    echo: 27
  }
``` - Mappings for the GPIO pins used for the HC-SR04

## Supervision

The [supervisor](./lib/supervisor.ex) starts a single child process (Circuit3b.RGB), and it specifies a `:one_for_one` strategy, which means if the child process dies, the supervisor will start a new one. 

## Application Logic

The application logic for this circuit is contained in the [Circuit3b.RGB module](./lib/rgb.ex).

```elixir
@led_gpios Application.compile_env!(:circuit3b, :led_gpios)

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end
``` 

First we set up a module attribute with our LED GPIO pins because we will need to access them later.  Our start_link is basically boilerplate.

```elixir
  # --- Callbacks ---
  @impl true
  def init(_) do
    # Get our HCSR04 config and start the HCSR04 GenServer
    hcsr04_config = Application.fetch_env!(:circuit3b, :hcsr04)
    {:ok, hcsr04_ref} = HCSR04.start_link({hcsr04_config.echo, hcsr04_config.trigger})

    # Kick off recursive task to light our LED
    Task.async(fn -> light_loop(hcsr04_ref) end)

    # Store our references in state so they don't get garbage collected
    {:ok, %{hcsr04_ref: hcsr04_ref}}
  end
```

We have no public API, and the only callback is the initialization which kicks off our HCSR04 process and starts a recursive loop to determine what colour the LED should be

```elixir
# Private Implementation
  defp light_loop(hcsr04_ref) do
    with :ok             <- HCSR04.update(hcsr04_ref),
         {:ok, distance} <- HCSR04.info(hcsr04_ref)
      do
        light_led(distance)
      else
        {:error, code} ->
          Logger.error("Error received when obtaining HCSR04 Reading: #{code}")
      end
    :timer.sleep(50)
    light_loop(hcsr04_ref)
  end
```

The light loop getsa a new reading from the HCSRO4 and then updates the LED colour, then it sleeps for 50ms and then calls itself again.

```elixir
 # <25 CM, Light LED Red
  defp light_led(distance) when distance < 25 do
    Pigpiox.Pwm.gpio_pwm(@led_gpios.red, 250)
    Pigpiox.Pwm.gpio_pwm(@led_gpios.green, 0)
    Pigpiox.Pwm.gpio_pwm(@led_gpios.blue, 0)
  end
  # <50cm, Light LED Yellow
  defp light_led(distance) when distance < 50 do
    Pigpiox.Pwm.gpio_pwm(@led_gpios.red, 250)
    Pigpiox.Pwm.gpio_pwm(@led_gpios.green, 250)
    Pigpiox.Pwm.gpio_pwm(@led_gpios.blue, 0)
  end
  # >50cm, Light LED Green
  defp light_led(_distance) do
    Pigpiox.Pwm.gpio_pwm(@led_gpios.red, 0)
    Pigpiox.Pwm.gpio_pwm(@led_gpios.green, 250)
    Pigpiox.Pwm.gpio_pwm(@led_gpios.blue, 0)
  end
```

The LED loop simply controls the LED based on the distance that is fed in, and since we're using PWM we don't need to open GPIOs or anything, we just need the pin numbers and Pigpiox does the rest.
