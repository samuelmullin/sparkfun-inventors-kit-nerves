# Circuit 4a

## Overview

This circuit displays text on the connected LCD Screen module.

## Usage

After [creating and uploading the firmware](../../FIRMWARE.md), and after a startup time of 30s or so, you should be able to see the text "Hello Nerves" print on the first line of the screen, followed by "42" on the second.

If the text doesn't appear as expected, try adjusting the potentiometer as it controls the contrast.  If the contrast is too low, nothing will appear, and if it's too high the boxes will all be black.

If it still doesn't work, refer to the [Troubleshooting Guide](../../TROUBLESHOOTING.md)

## Hardware

In order to complete this circuit, you'll need the following:

- 1 x Breadboard
- 8 x M-F Jumper cables
- 8 x M-M Jumper cables
- 1 x Analog Potentiometer
- 1 x HD44780 Based 16x2 LCD Screen

## Wiring

Start by connecting the 5v rail on the raspberry pi to the power rail on the right side of your breadboard and the ground on the raspberry pi to the ground rail on the left hand side of the breadboard.

First let's plug the potentiometer into the breadboard.  We're going to use it to adjust the contrast of the LCD, so connect the topmost pin to the 5v rail and the bottommost pin to the ground rail.  We'll plug the middle pin into the LCD in a moment.

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



## Application Definition & Dependencies

Our [application](./mix.exs) simply starts the Circuit4a module.

We have one non-standard dependencies for this project:

[lcd_display](https://hexdocs.pm/lcd_display/readme.html) which allows for control of our HD44780 display

## Config

The [config](./config/config.exs) for Circuit4a defines the following:

config :circuit4a,
  lcd_config: %{
    pin_rs: 21,
    pin_en: 16,
    pin_d4: 22,
    pin_d5: 23,
    pin_d6: 24,
    pin_d7: 25
  }

This is the config for the GPIO pins we'll use to control the LCD

## Supervision

The [supervisor](./lib/supervisor.ex) starts a single child process (Circuit4a.Screen), and it specifies a `:one_for_one` strategy, which means if the child process dies, the supervisor will start a new one. 

## Application Logic

The application logic for this circuit is contained in the [Circuit4a.Screen module](./lib/screen.ex).

```elixir
 defmodule Circuit4a.Screen do
  use GenServer

  require Logger

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # --- Callbacks ---
  @impl true
  def init(_) do
    # Get our LCD config and start the LCD GenServer
    lcd_config = Application.fetch_env!(:circuit4a, :lcd_config)
    {:ok, lcd_ref} = LcdDisplay.HD44780.GPIO.start(lcd_config)

    # Clear the screen
    LcdDisplay.HD44780.GPIO.execute(lcd_ref, :clear)

    # Print the first line
    LcdDisplay.HD44780.GPIO.execute(lcd_ref, {:print, "Hello, Nerves!"})

    # Move cursor to start of second line
    LcdDisplay.HD44780.GPIO.execute(lcd_ref, {:set_cursor, 1, 0})

    # Print second line
    LcdDisplay.HD44780.GPIO.execute(lcd_ref, {:print, "42"})

    # Store our references in state so they don't get garbage collected
    {:ok, %{lcd_ref: lcd_ref}}
  end

end
```

The comments explain things pretty succinctly, but we start the LCD process, clear the screen, print a line, move the cursor, print another line and then exit.  There are no other commands, and there's no public or private API.  We'll worry about updating the display more frequently starting in [Circuit4b](../circuit4b/).
