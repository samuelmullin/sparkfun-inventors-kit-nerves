defmodule Circuit2c.SimonServer do
  use GenServer

  require Logger

  @round_length 30_000
  @max_sequence 5
  @buttons [:green, :yellow, :blue, :red]
  @default_settings %{mode: :single}

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # Public API

  def start(opts \\ []) do
    %{mode: mode} = Enum.into(opts, @default_settings)
    GenServer.call(__MODULE__, {:start, mode})
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

  # GenServer Callbacks

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
      _ -> GenServer.cast(__MODULE__, :timer_loss)
    end
    {:noreply, state}
  end

  @impl true
  def handle_call({:start, mode}, _from, state) do
    {:reply, :started, Map.merge(state, %{game_status: :next_sequence, mode: mode, master_sequence: [], round_sequence: []})}
  end

  @impl true
  def handle_call(:end_game, _from, state) do
    {:reply, :ended, Map.merge(state, %{game_status: :done, master_sequence: [], round_sequence: []})}
  end

  @impl true
  def handle_call(:get_status, _from, %{game_status: game_status} = state) do
    {:reply, game_status, state}
  end

  @impl true
  def handle_call(:next_sequence, _from,  %{sequence: master_sequence, mode: :single} = state) when length(master_sequence) >= @max_sequence do
    {:reply, :win, Map.merge(state, %{game_status: :win})}
  end

  @impl true
  def handle_call(:next_sequence, _from, %{master_sequence: master_sequence, mode: :single} = state) do
    master_sequence = master_sequence ++ [Enum.random(@buttons)]
    {:reply, master_sequence, Map.merge(state, %{game_status: :next_button, master_sequence: master_sequence, round_sequence: master_sequence})}
  end

  @impl true
  def handle_call(:next_sequence, _from, %{master_sequence: master_sequence, mode: :vs} = state) do
    {:reply, master_sequence, Map.merge(state, %{game_status: :next_button, master_sequence: master_sequence, round_sequence: master_sequence})}
  end

  @impl true
  def handle_call({:validate_input, input}, _from, %{game_status: :next_button, master_sequence: master_sequence, round_sequence: [], mode: :vs} = state) do
    master_sequence = master_sequence ++ [input]
    {:reply, :next_sequence, Map.merge(state, %{game_status: :next_sequence, master_sequence: master_sequence})}
  end

  @impl true
  def handle_call({:validate_input, input}, _from, %{game_status: :next_button, master_sequence: master_sequence, round_sequence: [next | rest], mode: mode} = state) do
    game_status = validate_input(input, next, rest, master_sequence, mode)
    {:reply, game_status, Map.merge(state, %{game_status: game_status, round_sequence: rest})}
  end

  @impl true
  def handle_call({:validate_input, _input}, _from, state) do
    {:reply, :no_validation, state}
  end

  @impl true
  def handle_call(:reset_timer, _from, state) do
    lose_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(@round_length, :millisecond)
    {:reply, :ok, Map.put(state, :lose_at, lose_at)}
  end

  @impl true
  def handle_cast(:timer_loss, state) do
    {:noreply, Map.merge(state, %{game_status: :lose, lose_at: nil})}
  end

  # Private Implementation

  defp validate_input(input, expected, remaining, master, :single)
    when input == expected and length(remaining) == 0 and length(master) >=  @max_sequence, do: :win
  defp validate_input(input, expected, remaining, _master, :single)
    when input == expected and length(remaining) == 0, do: :next_sequence
  defp validate_input(input, expected, remaining, _master, :vs)
    when input == expected and length(remaining) == 0, do: :next_button
  defp validate_input(input, expected, _remaining, _master, _mode)
    when input == expected, do: :next_button
  defp validate_input(input, expected, _remaining, _master, _mode)
    when input != expected, do: :lose

end
