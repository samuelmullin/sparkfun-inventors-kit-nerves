# Circuit 2B

## Overview

This circuit acts as a digital trumpet.  When a button is pressed, a tone is played, and when the button is released it stops.  If a second(or third) button is pressed without releasing the first, the new tone will play.  Tones are stacked in a last-in-first-out manner, so when a button is released, the tone for the last button that was pressed (and is still pressed) will play.

## Usage

After [creating and uploading the firmware](../../FIRMWARE.md), and after a startup time of 30s or so, you should be able to press the button to play notes. Turning the potentiometer should adjust the volume.

If you cannot hear any notes, or if only some of the notes work, check the polarity of your Piezo buzzer, the wiring of the potentiometer and that you are using a hardware PWM GPIO for the buzzer. If it still doesn't work, refer to the [Troubleshooting Guide](../../TROUBLESHOOTING.md)

## Hardware

In order to complete this circuit, you'll need the following:

- 1 x Breadboard
- 1 x Piezo Buzzer
- 1 x Analog Potentiometer
- 3 x Coloured button
- 5 x M-F Jumper Cables
- 5 x M-M Jumper Cables

## Wiring

[Need a diagram or a picture here]

Start by connecting the ground on the raspberry pi to the ground rail on the right side of your breadboard.

Plug the piezo buzzer and potentiometer into the breadboard on the right hand side, ensuring that they are plugged in vertically (across multiple rows) and not horizontally.

Plug the button in bridging the left and right sides of the breadboard.

The piezo buzzer may have markings to indicate its polarity.  If it does, follow the markings, and otherwise just assume that the topmost pin is positive.  Plug a jumper from the negative side to the ground rail to the topmost pin of the potentiometer, and then another from the middle pin of the potentiometer to the ground rail on the right side of the breadboard.

Connect GPIO 12 to the positive pin of your piezo buzzer.

Plug the three buttons into the breadboard bridging the left and right side.  On the right hand side of each button, connect the row with the bottommost pin to the ground rail on the right side of the breadboard.  Also on the right hand side each button, connect the row with the topmost pin to the GPIO for that button - the default is GPIO 16 for blue, GPIO 20 for red and GPIO 21 for yellow.


## Application Definition & Dependencies

Our [application](./mix.exs) simply starts the Circuit2a module.

We have two non-standard dependencies for this project:

[circuits_gpio](https://hexdocs.pm/circuits_gpio/Circuits.GPIO.html) which allows for reading and writing to the GPIO pins on the raspberry pi
[:pigpiox](LINK GOES HERE) which allows us to use PWM with our GPIOs

## Config

The [config](./config/config.exs) for Circuit1b defines the following:

`buzzer_gpio: 12` - Denotes the GPIO pin the piezo buzzer is attached to.  This has to be a hardware GPIO pin on the raspberry pi.
```elixir
  buttons: %{
    20 => %{
      colour: :red,
      tone: 262
    },
    16 => %{
      colour: :blue,
      tone: 294
    },
    21 => %{
      colour: :yellow,
      tone: 330
    }
  }
```

This block maps the button GPIOs to their colour (mostly unimportant but helpful for troubleshooting) and their tone.

## Supervision

The [supervisor](./lib/supervisor.ex) starts a single child process (Circuit2b.Trumpet), and it specifies a `:one_for_one` strategy, which means if the child process dies, the supervisor will start a new one. 

## Application Logic

The application logic for this circuit is contained in the [Circuit2b.Trumpet module](./lib/trumpet.ex).


```elixir
  # --- Callbacks ---

  @impl true
  def init(_) do
    # Initialize GPIOs
    gpios = Enum.map(buttons(), fn {gpio, _config} -> setup_gpio(gpio) end)

    # We have to keep the GPIOs in state, otherwise we stop receiving messages!
    {:ok, %{active_tones: [], gpios: gpios}}
  end
  end
```

The init sets up the GPIOs for each of our buttons, including setting interrupts.  It stores the GPIO references in state and initializes an empty list of active tones.

```elixir
  @impl true
  def handle_info({:circuits_gpio, gpio, _timestamp, 1}, %{active_tones: active_tones} = state) do
    Logger.info("Deregister #{gpio} #{tone(gpio)} #{inspect active_tones}")
    {:noreply, Map.put(state, :active_tones, deregister_tone(tone(gpio), active_tones))}
  end

  @impl true
  def handle_info({:circuits_gpio, gpio, _timestamp, 0}, %{active_tones: active_tones} = state) do
    Logger.info("Register #{gpio} #{tone(gpio)} #{inspect active_tones}")
    {:noreply, Map.put(state, :active_tones, register_tone(tone(gpio), active_tones))}
  end
```

These callbacks handle registering and deregistering tones as buttons are pressed and released.

```elixir
  # --- Private Implementation ---

  defp register_tone(tone, active_tones) do
    case tone in active_tones do
      true -> active_tones
      false ->
        Pigpiox.Pwm.hardware_pwm(buzzer_gpio(), tone, @default_volume)
        [tone | active_tones]
    end
  end
```
`register_tone/2` checks if the tone is already active, and if it isn't, it has the buzzer play that tone and adds it to the front of the active tones list.

```elixir
  defp deregister_tone(_tone, active_tones) when length(active_tones) <= 1 do
    Pigpiox.Pwm.hardware_pwm(buzzer_gpio(), 0, 0)
    []
  end

  defp deregister_tone(tone, [active_tone | _ ] = active_tones) when tone == active_tone do
    active_tones = List.delete_at(active_tones, 0)
    Pigpiox.Pwm.hardware_pwm(buzzer_gpio(), List.first(active_tones), @default_volume)
    active_tones
  end

  defp deregister_tone(tone, active_tones) do
    active_tones
    |> Enum.reject(fn active_tone -> active_tone == tone end)
  end
```
`deregister_tone/2` has three possible paths.  If the list of active_tones is empty, it simply turns the buzzer off.  If the tone being deregistered is currently active, it deletes that tone from the list and plays the new first tone.  If the tone being deregistered is not currently active, it's simply removed from the active tones list.

```elixir
  defp setup_gpio(gpio) do
    Logger.info("Setting up gpio: #{gpio}")
    {:ok, gpio_addr} = GPIO.open(gpio, :input, pull_mode: :pullup)
    Circuits.GPIO.set_interrupts(gpio_addr, :both)
    gpio_addr
  end

  defp tone(gpio), do: buttons()[gpio].tone
  defp buttons(), do: Application.get_env(:circuit2b, :buttons)
  defp buzzer_gpio(), do: Application.get_env(:circuit2b, :buzzer_gpio)
```

`setup_gpio/1` - Opens the specified GPIO and sets the interrupts we require for this circuit.
`tone/1` - Pulls the tone out of the button config stanza
`buttons/0` and `buzzer_gpio/0` are helpers to pull values form the config.
