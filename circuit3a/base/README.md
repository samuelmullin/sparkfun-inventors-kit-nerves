# Circuit 3a

## Overview

This circuit moves a servo based on input from a potentiometer.

## Usage

After [creating and uploading the firmware](../../FIRMWARE.md), and after a startup time of 30s or so, you should be able to move the servo by adjusting the potentiometer.

If the servo does not move as expected, check that the wiring is correct. If it still doesn't work, refer to the [Troubleshooting Guide](../../TROUBLESHOOTING.md)

## Hardware

In order to complete this circuit, you'll need the following:

- 1 x Breadboard
- 5 x M-F Jumper cables
- 6 x M-M Jumper cables
- 1 x Analog Potentiometer
- 1 x ADC1115 Analog-to-Digital Converter

## Wiring

[Need a diagram or a picture here]

Start by connecting the 3.3v rail on the raspberry pi to the power rail on the right side of your breadboard and the ground on the raspberry pi to the ground rail on the left hand side of the breadboard.


## Application Definition & Dependencies

Our [application](./mix.exs) simply starts the Circuit3a module.

We have three non-standard dependencies for this project:

[ads1115](https://hexdocs.pm/ads1115/readme.html) which allows for control of our ADS1115 analog to digital converter
[circuits_i2c](https://hexdocs.pm/circuits_gpio/Circuits.GPIO.html) which allows for communication with sensors on the I2C bus
[:pigpiox](https://hexdocs.pm/pigpiox/Pigpiox.html) which allows us to use PWM with our GPIOs

## Config

The [config](./config/config.exs) for Circuit3a defines the following:

`potentiometer_max_reading: 27375` - The max value we expect to receive from our potentiometer.  This may vary and it can be adjusted up or down if things are not behaving as expected

`adc1115_address: 72` - The default for the ADS1115, but since it can be changed it is not hard coded.

`adc_gain: 4096` - ADC Gain explanation goes here

```elixir
analog_inputs: %{
  potentiometer: :ain0
}
```
 Mappings from the analog input pins to the sensors we are using.

`servo_gpio: 12` - The GPIO we will use to control our servo. Note that this is one of the hardware PWM pins for the Raspberry Pi.

`servo_range: {800, 2200}` - The high/low values for the PWM signal we will send our servo.  Going below or above these values will potentially damage the servo as it tries to rotate outside it's range of motion.


## Supervision

The [supervisor](./lib/supervisor.ex) starts a single child process (Circuit1d.RGB), and it specifies a `:one_for_one` strategy, which means if the child process dies, the supervisor will start a new one. 

## Application Logic

The application logic for this circuit is contained in the [Circuit3a.Servo module](./lib/servo.ex).

There is no public API for our Servo GenServer outside of the `start_link/1` boilerplate.

```elixir
  # --- Callbacks ---
  @impl true
  def init(_) do
    {servo_min, servo_max} = @servo_range

    # Determine how far the servo should move when the potentiometer is moved
    servo_step = ((servo_max - servo_min) / @potentiometer_max)

     # Open I2C-1 for input
     {:ok, ads_ref} = I2C.open("i2c-1")

     # Kick off recursive task to move our Servo
     Task.async(fn -> servo_loop(ads_ref, servo_min, servo_step) end)

     # Store our references in state so they don't get garbage collected
     {:ok, %{ads_ref: ads_ref, servo_step: servo_step}}
  end
```

The only callback implemented is the `init/1`, which gets our servo range and the steps-per-unit of our servo to use for the potentiometer readings then opens the I2C connection for our ADS1115 and kicks off a recursive loop to move the servo in response to adjusting the potentiometer.

```elixir
# --- Private Implementation ---

  defp servo_loop(ads_ref, servo_min, servo_step) do
    # Get current potentiometer reading
    {:ok, potentiometer_reading} = get_reading(ads_ref, :potentiometer)

    # Determine servo position using reading
    new_servo_position = servo_min + round(potentiometer_reading * servo_step)

    # Move servo to desired position
    Pigpiox.GPIO.set_servo_pulsewidth(@servo_gpio, new_servo_position)

    # Do it again
    servo_loop(ads_ref, servo_min, servo_step)
  end

  defp get_reading(ads_ref, sensor) do
    sensor_address = Map.get(@analog_inputs, sensor)
    # It's possible to get a transient error - if we do, catch it and wait before our next reading.
    case ADS1115.read(ads_ref, @ads1115_address, {sensor_address, :gnd}, @adc_gain) do
      {:error, :i2c_nak} ->
        Logger.error("Error getting reading, sleeping 5ms")
        :timer.sleep(5)
         get_reading(ads_ref, sensor)
      {:ok, reading} ->
        {:ok, reading}
    end
  end
```

The private implementation consists of two functions, `get_reading/2` which gets a reading for the potentiometer from the ADS1115 and `servo_loop/3` which calls `get_reading/2`, determines the pulse width we should send to the servo (between the min and the max defined in the config), sends the pulse to the servo and then calls itself again.



