# Circuit 2A

## Overview

For this challenge, the Trumpet is modified so that holding down different combinations of buttons plays different notes.

## Usage

After [creating and uploading the firmware](../../FIRMWARE.md), and after a startup time of 30s or so, you should be able to play different tones by pressing different combinations of buttons.

## Hardware

There are no changes to the hardware from the base circuit

## Wiring

There are no changes to the wiring from the base circuit


## Application Definition & Dependencies

There are no changes to the Application definition or Dependencies from the base circuit.

## Config

The [config](./config/config.exs) has been modified so that buttons map directly to colours, since tones are now handled within the private implementation:

```elixir
config :circuit2b,
  buzzer_gpio: 12,
  buttons: %{
    20 => :red,
    16 => :blue,
    21 => :yellow
  }
```

## Supervision

There are no changes to the Supervision tree from the base circuit.

## Application Logic

```elixir
# --- Callbacks ---

@impl true
def init(_) do
  # Initialize GPIOs
  gpios = Enum.map(buttons(), fn {gpio, _colour} -> setup_gpio(gpio) end)

  # We have to keep the GPIOs in state, otherwise we stop receiving messages!
  {:ok, %{active_colours: [], gpios: gpios}}
end

@impl true
def handle_info({:circuits_gpio, gpio, _timestamp, 1}, %{active_colours: active_colours} = state) do
  {:noreply, Map.put(state, :active_colours, deregister_colour(colour(gpio), active_colours))}
end

@impl true
def handle_info({:circuits_gpio, gpio, _timestamp, 0}, %{active_colours: active_colours} = state) do
  {:noreply, Map.put(state, :active_colours, register_colour(colour(gpio), active_colours))}
end
```

The only change here is replacing "tone(s)" with "colour(s)".

```elixir
  # --- Private Implementation ---

defp register_colour(colour, active_colours) do
  case colour in active_colours do
    true -> active_colours
    false ->
      active_colours = [colour | active_colours]
      |> Enum.sort()

      Pigpiox.Pwm.hardware_pwm(buzzer_gpio(), tone(active_colours), @default_volume)
      active_colours
  end
end

defp deregister_colour(_colour, active_colours) when length(active_colours) <= 1 do
  Pigpiox.Pwm.hardware_pwm(buzzer_gpio(), 0, 0)
  []
end

defp deregister_colour(colour, active_colours) do
  active_colours = active_colours
  |> Enum.reject(fn active_colour -> active_colour == colour end)

  Pigpiox.Pwm.hardware_pwm(buzzer_gpio(), tone(active_colours), @default_volume)
  active_colours
end
```

Similarly, the private implementation has been updated to register and deregister colours.  The colours in the active colours list are always kept sorted so they can be used to match against the colour lists when determining tones.

```elixir
defp tone([:blue]),                do: 262
defp tone([:red]),                 do: 294
defp tone([:yellow]),              do: 330
defp tone([:blue, :red]),          do: 349
defp tone([:blue, :yellow]),       do: 392
defp tone([:red, :yellow]),        do: 440
defp tone([:blue, :red, :yellow]), do: 494
```

Each of these corresponds to a set of pressed buttons and returns the tone that will be played for that combination.





