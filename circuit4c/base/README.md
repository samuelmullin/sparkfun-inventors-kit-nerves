# Circuit 4c

## Overview

This circuit implements a who-am-i game using an LCD screen, a button and a piezo buzzer.

## Usage

After [creating and uploading the firmware](../../FIRMWARE.md), and after a startup time of 30s or so, you should be able to play a game of who-am-i.  There's a lot of moving parts here, so see the [Troubleshooting Guide](../../TROUBLESHOOTING.md) if things aren't working the way you expect.

## Hardware

In order to complete these circuits, you'll need the following:

- 1 x Breadboard
- 10 x M-F Jumper cables
- 11 x M-M Jumper cables
- 1 x Analog Potentiometer
- 1 x HD44780 Based 16x2 LCD Screen
- 1 x Push button
- 1 x Piezo Buzzer

## Wiring

This time around we're just going to use the 5v rail so it's a bit simpler.  Hook the 5v from the raspberry pi up to one of the power rails and the ground up to one of the ground rails.

Next let's plug the potentiometer into the breadboard.  We're going to use it to adjust the contrast of the LCD, so connect the topmost pin to the 5v rail and the bottommost pin to the ground rail.  We'll plug the middle pin into the LCD in a moment.

Plug the LCD screen into the breadboard.  The pins are located on the top-left corner of the LCD module, whichever direction you connect it, you are going to count the pins starting at 1 from that top left pin.  There are 16 pins in total, so let's connect them from top to bottom.

1) Connect to the ground rail
2) Connect to the 5v rail
3) Connect to the middle pin of the potentiometer
4) Connect to GPIO 21
5) Connect to the ground rail
6) Connect to GPIO 16
7) Unused
8) Unused
9) Unused
10) Unused
11) Connect to GPIO 22
12) Connect to GPIO 23
13) Connect to GPIO 24
14) Connect to GPIO 25
15) Connect to 5v rail
16) Connect to Ground rail

Next we'll hook up the buzzer, which needs to be connected to GPIO 12 (for PWM) and the ground rail.  Note that Piezo buzzers are often polarized so make sure you connect the GPIO to the positive side.

Finally, we'll hook up the button.  The button needs to be plugged in bridging the left and right side of the board or it will always regsister as on! Connect one side to GPIO 18 and on the other side to the ground rail.

## Application Definition & Dependencies

Our [application](./mix.exs) simply starts the Circuit4c module.

We have three non-standard dependencies for this project:

[circuits_gpio](https://hexdocs.pm/circuits_gpio/Circuits.GPIO.html) which allows for reading and writing to the GPIO pins on the raspberry pi
[lcd_display](https://hexdocs.pm/lcd_display/readme.html) which allows for control of our HD44780 display
[:pigpiox](https://hexdocs.pm/pigpiox/Pigpiox.html) which allows us to use PWM with our GPIOs

## Config

The [config](./config/config.exs) for Circuit4c defines the following:

```elixir
config :circuit4c,
  lcd_config: %{
    pin_rs: 21,
    pin_en: 16,
    pin_d4: 22,
    pin_d5: 23,
    pin_d6: 24,
    pin_d7: 25
  },
  ```
  This is the config we'll use for the LCD display

  ```elixir
  buzzer_pin: 12,
  button_pin: 18
  ```

  These are the pins we'll use to connect the buzzer (PWM) and the button (GPIO).

## Supervision

The [supervisor](./lib/supervisor.ex) starts a single child process (Circuit4c.WhoAmI), and it specifies a `:one_for_one` strategy, which means if the child process dies, the supervisor will start a new one. 

## Application Logic

The application logic for this circuit is contained in the [Circuit4c.WhoAmI module](./lib/who_am_i.ex).  This is one of the biggest applications we have written so far so there is a lot of logic to cover.

```elixir
 defmodule Circuit4c.WhoAmI do
  use GenServer

  require Logger

  alias Circuits.GPIO
  alias LcdDisplay.HD44780.GPIO, as: LCD

  @default_words [
    "apple",
    "banana",
    "orange",
    "grape",
    "kiwi"
  ]

  @default_time_limit 30
  ```

  This section covers our imports and some module attributes, including the default word list.

  
  ```elixir
  defmodule GameState do
    defstruct base_words: [],
              time_limit: 0,
              current_word: "",
              remaining_words: nil,
              round_number: 0,
              timer: 0,
              status: :waiting,
              lcd_ref: nil,
              button_ref: nil,
              buzzer_pin: nil
  end
  ```

  This is a struct, which is like a Map but with defined defaults and guaranteed keys.  Using a struct lets us simplify our code by making our state structure predictable.  We can create an instance of this struct from within this module by creating an empty instance of the struct (`%GameState{}`), and we can update keys in the struct easily by using `struct/2`.  Read more about structs [in the docs](https://elixir-lang.org/getting-started/structs.html)!

  ```elixir
  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end
  ```

  This is just our start_link/1, nothing to see here.

  ```elixir
  # --- Callbacks ---

  @impl true
  def init(config) do
    # Get our LCD config and start the LCD GenServer
    lcd_config = Application.fetch_env!(:circuit4c, :lcd_config)
    {:ok, lcd_ref} = LCD.start(lcd_config)

    # Get our button reference and set our interrupt
    {:ok, button_ref} = GPIO.open(Application.fetch_env!(:circuit4c, :button_pin), :input, pull_mode: :pullup)
    GPIO.set_interrupts(button_ref, :falling)

    # Get our buzzer pin
    buzzer_pin = Application.fetch_env!(:circuit4c, :buzzer_pin)

    # Clear the screen and print the start message
    LCD.execute(lcd_ref, :clear)
    LCD.execute(lcd_ref, {:print, "Press to start!"})

    # Store our references and initialize our GameState
    state = struct(GameState, [
      lcd_ref: lcd_ref,
      button_ref: button_ref,
      buzzer_pin: buzzer_pin,
      time_limit: Keyword.get(config, :time_limit, @default_time_limit),
      base_words: Keyword.get(config, :words, @default_words)
    ])

    {:ok, state}
  end
  ```

  This might be the biggest init we have written, but we have a lot of things to do:

  - Start the LCD process, get the reference.
  - Get a reference to our button GPIO and set our interrupts so we know when the button was pressed
  - Display the initial message on the screen
  - Store all our references and some other config in a GameState struct

  ```elixir
  @impl true
  def handle_info({:circuits_gpio, _, _, _}, %GameState{status: :waiting} = state) do
    # If the game is waiting to start and the button is pushed, start the game.
    state = start_game(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:circuits_gpio, _, _, _}, %GameState{status: :started} = state) do
    # If the game is started and the button is pushed, begin the next round.
    state = next_round(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:circuits_gpio, _, _, _}, %GameState{} = state) do
    # If the button is pushed and the game is not started or waiting to start, ignore it.
    {:noreply, state}
  end
  ```

  These `handle_info/2` functions determine what to do when we see our button is pressed.  What we do depends on the current state of the game - if we're waiting, we start the game, if we're started, we move to the next round and if we're in any other state, we do nothing.

  ```elixir
  @impl true
  def handle_info(:tick, %GameState{timer: 1, status: :started} = state) do
    # If the timer is being ticked to zero, the game is lost
    Process.send_after(__MODULE__, :lose_sequence, 10)
    {:noreply, struct(state, [status: :lose])}
  end

  @impl true
  def handle_info(:tick, %GameState{status: :started} = state) do
    # If the game is started, tick the timer and set it to tick again in ~1000ms
    state = struct(state, [timer: state.timer - 1])
    update_display(state)
    Process.send_after(__MODULE__, :tick, 1000)

    {:noreply, state}
  end

  @impl true
  def handle_info(:tick, %GameState{} = state) do
    # If the game is not started, do nothing (and stop ticking).
    {:noreply, state}
  end
  ```

  These `handle_info/2` functions are managing the timer.  What we do here is determined by the state of the timer and the state of the game.  If there is 1 second left and the game is in a started state, the player has lost and we go into the lose sequence.  If the game is started and there's more than one second left on the timer, we decrement the timer by 1 and schedule another ticket in 1 second.  If the game isn't started, we don't do anything.

  ```elixir
  @impl true
  def handle_info(:win_sequence, %GameState{status: :win} = state) do
    # Play the winning sequence
    win_sequence(state)

    # Reset the game
    Process.send_after(__MODULE__, :reset, 1)

    {:noreply, struct(state, [status: :pending_reset])}
  end

  @impl true
  def handle_info(:lose_sequence, %GameState{status: :lose} = state) do
    # Play the losing sequence
    lose_sequence(state)

    # Reset the game
    Process.send_after(__MODULE__, :reset, 1)

    {:noreply, struct(state, [status: :pending_reset])}
  end

  @impl true
  def handle_info(:reset, %GameState{status: :pending_reset} = state) do
    # Let the player know they can restart the game now
    LCD.execute(state.lcd_ref, {:set_cursor, 1, 0})
    LCD.execute(state.lcd_ref, {:print, "Press to restart!"})

    {:noreply, struct(state, [status: :waiting])}
  end
  ```

  These `handle_info/2` messages deal with the logic of winning, losing or resetting the game.  The actual logic for winning/losing is deferred to private functions, and the reset logic is simply updating the screen to invite the player to play again, and setting the status to waiting to stop ticking.

  ```elixir
  # --- Private Implementation ---

  defp update_display(state) do
    LCD.execute(state.lcd_ref, {:set_cursor, 0, 0})
    LCD.execute(state.lcd_ref, {:print, String.pad_trailing(state.current_word, 16)})
    LCD.execute(state.lcd_ref, {:set_cursor, 1, 0})
    LCD.execute(state.lcd_ref, {:print, "R: #{pad_number(state.round_number)} T: #{pad_number(state.timer)}"})
  end
  ```

  This function updates the display based on the current state.

  ```elixir
  defp start_game(state) do
    state = struct(state, [
      remaining_words: Enum.shuffle(state.base_words),
      timer: state.time_limit,
      round_number: 0,
      status: :started
    ])

    Process.send_after(__MODULE__, :tick, 1100)
    LCD.execute(state.lcd_ref, :clear)
    next_round(state)
  end
  ```

  Starting the game simply updates the state, starts the timer and moves the game to the next round.

  ```elixir

  defp next_round(%GameState{remaining_words: [], status: :started} = state) do
    Process.send_after(__MODULE__, :win_sequence, 10)
    struct(state, [status: :win])
  end

  defp next_round(state) do
    [current_word | remaining_words] = state.remaining_words
    round_number = state.round_number + 1
    state = struct(state, [current_word: current_word, remaining_words: remaining_words, round_number: round_number])
    update_display(state)
    state
  end
  ```

  `next_round/1` checks to see if there are any words left in the list, and if there aren't, then the player has won and we kick off the win sequence and update the state.  If there are still words left, we get the next word, increment the round and update the state before updating the display.

  ```elixir
  defp win_sequence(state) do
    LCD.execute(state.lcd_ref, :clear)
    LCD.execute(state.lcd_ref, {:set_cursor, 0, 0})
    LCD.execute(state.lcd_ref, {:print, "All Correct!!"})
    Music.win_notes(state.buzzer_pin)
  end

  defp lose_sequence(state) do
    LCD.execute(state.lcd_ref, :clear)
    LCD.execute(state.lcd_ref, {:set_cursor, 0, 0})
    LCD.execute(state.lcd_ref, {:print, "Correct: #{pad_number(state.round_number)}"})
    Music.lose_notes(state.buzzer_pin)
  end

  defp pad_number(number), do: number |> Integer.to_string |> String.pad_leading(2, "0")
end
```

The win sequence and lose sequence display info on the screen and play some notes over the buzzer.  Pad number 0 pads numbers so they always take up the same amount of space on the display.

```elixir
defmodule Music do
  def win_notes(buzzer_pin) do
    Enum.each([162, 212, 249, 212, 249, 240, 249], fn note ->
      Pigpiox.Pwm.hardware_pwm(buzzer_pin, note, 5_000)
      Process.sleep(400)
      Pigpiox.Pwm.hardware_pwm(buzzer_pin, note, 0)
      Process.sleep(10)
    end)
  end

  def lose_notes(buzzer_pin) do
    Enum.each([249, 240, 249, 212, 249, 212, 162], fn note ->
      Pigpiox.Pwm.hardware_pwm(buzzer_pin, note, 5_000)
      Process.sleep(400)
      Pigpiox.Pwm.hardware_pwm(buzzer_pin, note, 0)
      Process.sleep(10)
    end)
  end
end
```

A sneaky module inside our module!  This just separates out the song that plays for winning and losing.  For simplicity we just dumped it into the bottom of this module, but we could have put it in a separate file (`music.ex`) as well.
