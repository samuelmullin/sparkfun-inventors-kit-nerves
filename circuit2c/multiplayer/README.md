# Circuit 2C

## Overview

For this circuit, the game is modified to allow multiplayer support.  Each round, a player follows all the sequence from the previous round and then adds a new button of their own before passing the unit back to the next player.

There is no timer in this mode, players play until one of them loses.

## Usage

After [creating and uploading the firmware](../../FIRMWARE.md), and after a startup time of 30s or so, you should see and hear the startup sequence play.  At this point the first player can begin the sequence and pass the unit to the second player.

## Hardware

There is no deviation from the hardware included in the base version of the circuit.

## Wiring

There is no deviation from the wiring included in the base version of the circuit.

## Application Definition & Dependencies

There are no changes in the Application Definition or Dependencies from the base circuit.

## Config

There are no changes from the Config defined in the base circuit.

## Supervision

There is no difference from the supervisor described in the base circuit.

## Application Logic

The application logic for this circuit is split into the Client and the Server.

### SimonServer Logic

```elixir
@round_length_ms 30_000
  @max_sequence 5
  @buttons [:green, :yellow, :blue, :red]

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # Public API

  def start(opts \\ []) do
    GenServer.call(__MODULE__, :start)
  end

  def validate_input(input) do
    GenServer.call(__MODULE__, {:validate_input, input})
  end

  def next_sequence() do
    GenServer.call(__MODULE__, :next_sequence)
  end

  def reset_timer() do
    GenServer.call(__MODULE__, :reset_timer)
  end

  def game_status() do
    GenServer.call(__MODULE__, :get_status)
  end

  def end_game() do
    GenServer.call(__MODULE__, :end_game)
  end
```

First some global variables are defined, controlling the number of rounds to win and the default timeout to lose. Following that, a number of public methods are defined allowing the client to query and update the game state.  Logic for determining when to transition the game state (IE, was the guess correct, or did the player lose) is controlled by the Server.

```elixir
 # --- Callbacks ---

  @impl true
  def init(_) do
    Process.send_after(self(), :tick_timer, 100)
    {:ok, %{game_status: :ready, master_sequence: [], lose_at: nil}}
  end

  @impl true
  def handle_info(:tick_timer, %{lose_at: nil} = state) do
    Process.send_after(self(), :tick_timer, 100)
    {:noreply, state}
  end

  @impl true
  def handle_info(:tick_timer, %{lose_at: lose_at} = state) do
    case NaiveDateTime.compare(lose_at, NaiveDateTime.utc_now()) do
      :gt -> Process.send_after(self(), :tick_timer, 100)
      _ ->
        GenServer.cast(__MODULE__, :timer_loss)
        Process.send_after(self(), :tick_timer, 100)
    end
    {:noreply, state}
  end
```

The first set of callbacks deal with the recursive loop that maintains the round timer.  On each tick, the process will check if we have exceeded the lose_at timestamp.  If so, a message is sent indicating a timer loss.  In either case, the process then sends itself another message in 100ms to check again.

```elixir
  @impl true
  def handle_call(:start, _from, state) do
    {:reply, :started, Map.merge(state, %{game_status: :next_sequence, master_sequence: [], round_sequence: []})}
  end

  @impl true
  def handle_call(:end_game, _from, state) do
    {:reply, :ended, Map.merge(state, %{game_status: :done, master_sequence: [], round_sequence: []})}
  end
``` 

The next set of callbacks simply tell the server to update the state of the game by either starting it (creating an empty sequence) or ending it (clearing the sequence and setting the status to done),


```elixir
  @impl true
  def handle_call(:get_status, _from, %{game_status: game_status} = state) do
    {:reply, game_status, state}
  end
```

This callback simply lets the client query the status of the game.

```elixir
  @impl true
  def handle_call(:next_sequence, _from,  %{sequence: master_sequence} = state) when length(master_sequence) >= @max_sequence do
    {:reply, :win, Map.merge(state, %{game_status: :win})}
  end

  @impl true
  def handle_call(:next_sequence, _from, %{master_sequence: master_sequence} = state) do
    master_sequence = master_sequence ++ [Enum.random(@buttons)]
    {:reply, master_sequence, Map.merge(state, %{game_status: :next_button, master_sequence: master_sequence, round_sequence: master_sequence})}
  end

  @impl true
  def handle_call({:validate_input, input}, _from, %{game_status: :next_button, master_sequence: master_sequence, round_sequence: [next | rest]} = state) do
    game_status = validate_input(input, next, rest, master_sequence)
    {:reply, game_status, Map.merge(state, %{game_status: game_status, round_sequence: rest})}
  end

  @impl true
  def handle_call({:validate_input, _input}, _from, state) do
    {:reply, :no_validation, state}
  end

```

`next_sequence` either marks the game as won, returning `:win`, or appends a new colour to the sequence and returns the new sequence.  `{validate_input, input}`checks that the input provided by the user is correct by calling the private function validate_input).

```elixir
  @impl true
  def handle_call(:reset_timer, _from, state) do
    lose_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(@round_length_ms, :millisecond)
    {:reply, :ok, Map.put(state, :lose_at, lose_at)}
  end

  @impl true
  def handle_cast(:timer_loss, state) do
    {:noreply, Map.merge(state, %{game_status: :lose, lose_at: nil})}
  end
```

`reset_timer` is called whenever a new round is started, and `timer_loss` is called when the timer loop determines that the user has run out of time.

```elixir
  # Private Implementation

  defp validate_input(input, expected, remaining, master)
    when input == expected and length(remaining) == 0 and length(master) >=  @max_sequence, do: :win
  defp validate_input(input, expected, remaining, _master)
    when input == expected and length(remaining) == 0, do: :next_sequence
  defp validate_input(input, expected, _remaining, _master)
    when input == expected, do: :next_button
  defp validate_input(input, expected, _remaining, _master)
    when input != expected, do: :lose
```

`validate_input/4` defines the core logic for validating that a button press is correct.  Each button press will result in one of four outcomes:
  `:next_button` - The button press was correct, but it is not the last in the sequence.
  `:next_sequence` - The button press was correct and it was the last in the sequence, but we haven't reached the max sequence length yet.
  `win` - The button press was correct, it was the last in the sequence and we have reached the max sequence length.
  `:lose` - The button press was wrong.


### SimonClient Logic

```elixir
@default_volume 500_000 # 50%
@interval_ms 250
@buzzer_pin Application.get_env(:circuit2c, :buzzer_pin)

@colours [:green, :red, :blue, :yellow]

# Setup pin to name map (at compile time)
@gpio_names @colours
|> Enum.reduce(%{}, fn colour, acc -> Map.put(acc, Application.get_env(:circuit2c, String.to_atom("#{colour}_input_pin")), colour) end)

def start_link(_) do
  GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
end
```

To start, there's some module attributes, including a couple (`@buzzer_pin` and `@gpio_names`) that are calculated values.  Keep in mind these are set at compile time.

```elixir

# --- Callbacks ---

@impl true
def init(_) do
  # Initialize GPIOs for button/led for each colour
  gpios = Enum.reduce(@colours, %{}, fn colour, acc ->

    {:ok, input_gpio} = GPIO.open(input_pin(colour), :input, pull_mode: :pullup)
    Circuits.GPIO.set_interrupts(input_gpio, :both)
    {:ok, led_gpio} = GPIO.open(led_pin(colour), :output)

    config = %{
      input_gpio: input_gpio,
      led_gpio: led_gpio
    }

    Map.put(acc, colour, config)
  end)

  # Start the game
  start_game(gpios)

  # Enter game loop async so we can end our init process
  Task.async(fn -> game_loop(gpios) end)

  {:ok, %{gpios: gpios, input_state: :waiting}}
end

```

`init/1` initializes the gpios, does the initial game start and then starts an async loop for the main game process.

```elixir
# Handle messages from circuits_gpio indicating our input state has changed
@impl true
def handle_info({:circuits_gpio, pin, _timestamp, gpio_state}, %{gpios: gpios, input_state: input_state} = state) do
  pin
  |> gpio_name()
  |> handle_gpio_state(gpio_state, input_state, gpios)

  {:noreply, state}
end

@impl true
def handle_call(:waiting, _from, state) do
  {:reply, :ok, Map.put(state, :input_state, :waiting)}
end

@impl true
def handle_cast(:accept_input, state) do
  {:noreply, Map.put(state, :input_state, :accept_input)}
end
```

The balance of the callbacks are handling button presses and setting the input_state to determine if we should accept more button presses.

```elixir
# --- Private Implementation ---
defp start_game(gpios) do
  SimonServer.start()
  start_sequence(gpios)
end

defp end_game(), do: SimonServer.end_game()
```

`start_game/1` and `end_game/0`  start and end the game respectively on the server.

```elixir
defp game_loop(gpios) do
  Process.sleep(100) # debounce
  case SimonServer.game_status() do
    :next_sequence ->
      # Set waiting state and pause momentarily
      GenServer.call(__MODULE__, :waiting)
      Process.sleep(500)

      # Get next sequence and display for player
      SimonServer.next_sequence()
      |> handle_sequence(gpios)

    :next_button ->
      game_loop(gpios)
    :win ->
      win_sequence(gpios)
    :lose ->
      lose_sequence(gpios)
    :done ->
      :ok
  end

  # The game ended, start it again!
  start_game(gpios)
  game_loop(gpios)
end
```

After sleeping 100ms, `game_loop/1` (which is running in it's own process) queries the server for the game status and then proceeds accordingly:

 - `:next_sequence` indicates that it's time to start the new round by retrieving and playing a new sequence for the player.  This continues the game loop.

 - `next_button` indicates that we are in the middle of a sequence and waiting for the player input.  This continues the game loop.

 - `win` indicates the player has won the game.  This plays the win sequence, after which the game is restarted.

 - `lose` indicates that the player has lost the game.  This plays the lose sequence, after which the game is restarted.

 - `done` means the game was ended manually (without a win or lose).  This restarts the game.


```elixir
defp handle_gpio_state(colour, 0, :accept_input, gpios) when colour in @colours, do: select_colour(colour, gpios)
defp handle_gpio_state(colour, 1, :accept_input, gpios) when colour in @colours do
  deselect_colour(colour, gpios)
  SimonServer.validate_input(colour)
end
defp handle_gpio_state(name, _, _, _), do: :ok
```

This block handles button input - it is ignored if the `input_state` is not `:accept_input`, and otherwise the selected button has it's tone/led (de)activated.

```elixir
defp start_sequence(gpios) do
  Enum.each(@colours, fn colour ->
    Pigpiox.Pwm.hardware_pwm(@buzzer_pin, tone(colour), @default_volume)
    GPIO.write(gpios[colour][:led_gpio], 1)
    Process.sleep(100)
    Pigpiox.Pwm.hardware_pwm(@buzzer_pin, 0, 0)
    GPIO.write(gpios[colour][:led_gpio], 0)
    Process.sleep(100)
  end)

  Process.sleep(500)
end

defp win_sequence(gpios) do
  Enum.each([200, 300, 400], fn starting_tone ->
    @colours
    |> Enum.with_index()
    |> Enum.each(fn {colour, index} ->
      Pigpiox.Pwm.hardware_pwm(@buzzer_pin, starting_tone + (20 * index), @default_volume)
      GPIO.write(gpios[colour][:led_gpio], 1)
      Process.sleep(100)
      GPIO.write(gpios[colour][:led_gpio], 0)
    end)
  end)
  Pigpiox.Pwm.hardware_pwm(@buzzer_pin, 0, 0)
  Process.sleep(500)
end

defp lose_sequence(gpios) do
  Enum.each(1..20, fn num ->
    Pigpiox.Pwm.hardware_pwm(@buzzer_pin, 600 - (20 * num), @default_volume)
    GPIO.write(gpios[:red][:led_gpio], 1)
    Process.sleep(50)
  end)
  Pigpiox.Pwm.hardware_pwm(@buzzer_pin, 0, 0)
  GPIO.write(gpios[:red][:led_gpio], 0)
  Process.sleep(500)
end
```

This block handles the unique sequences of lights/sounds for starting/winning/losing the game.  There's no reason they need to be this animated, but where's the fun in that?

```elixir
defp handle_sequence(:win, gpios), do: win_sequence(gpios)
defp handle_sequence(sequence, gpios) do
  sequence
  |> Enum.each(fn colour ->
    select_colour(colour, gpios)
    Process.sleep(@interval_ms)
    deselect_colour(colour, gpios)
    Process.sleep(@interval_ms)
  end)

  # Reset timer and accept input
  SimonServer.reset_timer()
  GenServer.cast(__MODULE__, :accept_input)
  game_loop(gpios)
  end

defp select_colour(colour, gpios) do
  Pigpiox.Pwm.hardware_pwm(@buzzer_pin, tone(colour), @default_volume)
  GPIO.write(gpios[colour][:led_gpio], 1)
end

defp deselect_colour(colour, gpios) do
  Pigpiox.Pwm.hardware_pwm(@buzzer_pin, 0, 0)
  GPIO.write(gpios[colour][:led_gpio], 0)
end

```

This block handles the more generic playing the sequence for each round.

```elixir

# Helpers to fetch our config vars
defp tone(colour), do: Application.get_env(:circuit2c, String.to_atom("#{colour}_tone"))
defp led_pin(colour), do: Application.get_env(:circuit2c, String.to_atom("#{colour}_led_pin"))
defp input_pin(name), do: Application.get_env(:circuit2c, String.to_atom("#{name}_input_pin"))
defp gpio_name(pin), do: Map.get(@gpio_names, pin)

end
```

And finally, the config helpers we know and love.