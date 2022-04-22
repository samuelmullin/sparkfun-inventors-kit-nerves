# Circuit 2A

## Overview

This circuit plays a song when it starts, and whenever the included button is pressed.  It also uses the potentiometer to control the volume.

## Usage

After [creating and uploading the firmware](../../FIRMWARE.md), and after a startup time of 30s or so, you should hear a rendition of happy birthday playing.  Turning the potentiometer should adjust the volume.  Pressing the buttom should play the song again.

If the song does not play as expected, check the polarity of your Piezo buzzer, the wiring of the potentiometer and that you are using a hardware PWM GPIO. If it still doesn't work, refer to the [Troubleshooting Guide](../../TROUBLESHOOTING.md)

## Hardware

In order to complete this circuit, you'll need the following:

- 1 x Breadboard
- 1 x Piezo Buzzer
- 1 x Analog Potentiometer
- 3 x M-F Jumper Cables
- 2 x M-M Jumper Cables

## Wiring

[Need a diagram or a picture here]

Start by connecting the ground on the raspberry pi to the ground rail on the right side of your breadboard.

Plug the piezo buzzer and potentiometer into the breadboard on the right hand side, ensuring that they are plugged in vertically (across multiple rows) and not horizontally.

Plug the button in bridging the left and right sides of the breadboard.

The piezo buzzer may have markings to indicate its polarity.  If it does, follow the markings, and otherwise just assume that the topmost pin is positive.  Plug a jumper from the negative side to the ground rail to the topmost pin of the potentiometer, and then another from the middle pin of the potentiometer to the ground rail on the right side of the breadboard.

Connect GPIO 12 to the positive pin of your piezo buzzer.

Connect the row with the topmost pin of the button to GPIO 26, and the row with the bottommost pin of your button to the ground rail on the right hand side of the breadboard.


## Application Definition & Dependencies

Our [application](./mix.exs) simply starts the Circuit2a module.

We have two non-standard dependencies for this project:

[circuits_gpio](https://hexdocs.pm/circuits_gpio/Circuits.GPIO.html) which allows for reading and writing to the GPIO pins on the raspberry pi
[:pigpiox](LINK GOES HERE) which allows us to use PWM with our GPIOs

## Config

The [config](./config/config.exs) for Circuit1b defines the following:

`buzzer_gpio: 12` - Denotes the GPIO pin the piezo buzzer is attached to.  This has to be a hardware GPIO pin on the raspberry pi.
`reset_gpio: 26` - Denotes the GPIO pin the button is attached to.

## Supervision

The [supervisor](./lib/supervisor.ex) starts a single child process (Circuit2a.Music), and it specifies a `:one_for_one` strategy, which means if the child process dies, the supervisor will start a new one. 

## Application Logic

The application logic for this circuit is contained in the [Circuit2a.Music module](./lib/music.ex).

```elixir
  # --- Public API ---

  def play_song(song \\ @default_song) do
    # Set playing to true before we start playing the song
    set_playing(true)
    GenServer.cast(__MODULE__, {:play_notes, song})
  end
```

Only one function is exposed in the public API, and it optionally accepts a string of notes which represent the notes in a song.  If no notes are provided, the default song (something like happy birthday) is played.  If a note is unsupported, no note is played but the song will continue.


```elixir
   # --- Callbacks ---
  @impl true
  def init(_) do
    # Open LED GPIO for output
    {:ok, reset_gpio} = GPIO.open(reset_gpio(), :input, pull_mode: :pullup)
    Circuits.GPIO.set_interrupts(reset_gpio, :falling)

    play_song()
    {:ok, %{reset_gpio: reset_gpio}}
  end
```

The init sets up the GPIO for the reset button and sets up an interrupt when the value is falling.  It then calls the `play_song/1` method from the public api.

```elixir

  @impl true
  def handle_cast({:play_notes, song}, state) do
    play_notes(song)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_playing, value}, state) do
    {:noreply, Map.merge(state, %{playing: value})}
  end

  @impl true
  def handle_info({:circuits_gpio, _pin, _timestamp, 0}, %{playing: false} = state) do
    play_song()
    {:noreply, state}
  end

  @impl true
  def handle_info({:circuits_gpio, _pin, _timestamp, 0}, state) do
    Logger.info("Already playing, ignoring button press")
    {:noreply, state}
  end
```

These callbacks handle playing the notes of the song that was provided, setting the `playing` value in the state and handling button presses (including ignoring them if a song is already playing).

```elixir
  # --- Private Implementation ---
  
  defp play_notes(song) do
    # Convert the song to lower case, then to individual characters (graphemes) then play each note.
    song
    |> String.downcase()
    |> String.graphemes()
    |> Enum.each(fn note -> play_note(note) end)

    # Set playing to false when we finish playing the song
    set_playing(false)
  end

  defp play_note(" "), do: Process.sleep(@interval_ms * 3)
  defp play_note(note) do
    Pigpiox.Pwm.hardware_pwm(buzzer_gpio(), Map.get(@notes, note, 0), 500_000) # On
    Process.sleep(@interval_ms * 3)
    Pigpiox.Pwm.hardware_pwm(buzzer_gpio(), Map.get(@notes, note, 0), 0) # Off
    Process.sleep(@interval_ms)
  end

  defp buzzer_gpio(), do: Application.get_env(:circuit2a, :buzzer_gpio)
  defp reset_gpio(), do: Application.get_env(:circuit2a, :reset_gpio)
```

`play_notes/1` is called, converts a string of notes to a lowercase list of single letters then calls `play_note/1` for each note.
`play_note/1` waits for 3 x `@interval_ms` if it is called with a space.  Otherwise, it sends a PWM signal to the piezo buzzer at the frequency of the note, if the note is found in `@notes`.  It then waits for 3 x `@interval_ms`, turns the buzzer off and waits another `@interval_ms` before moving on to the next note.

`buzzer_gpio()` and `reset_gpio()` are helpers to pull values from the config.