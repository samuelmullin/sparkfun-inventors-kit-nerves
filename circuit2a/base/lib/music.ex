defmodule Circuit2a.Music do
  use GenServer

  require Logger

  alias Circuits.GPIO

  @notes %{ # common note frequencies
    "c" => 262,
    "d" => 294,
    "e" => 330,
    "f" => 349,
    "g" => 392,
    "a" => 440,
    "b" => 494,
  }
  @interval_ms 100 # default interval in ms
  @default_song "ccdcfe ccdcgf ccdafed bbafgf"

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # --- Public API ---

  def play_song(song \\ @default_song) do
    # Set playing to true before we start playing the song
    set_playing(true)
    GenServer.cast(__MODULE__, {:play_notes, song})
  end

  # --- Callbacks ---

  @impl true
  def init(_) do
    # Open LED GPIO for output
    {:ok, reset_gpio} = GPIO.open(reset_gpio(), :input, pull_mode: :pullup)
    Circuits.GPIO.set_interrupts(reset_gpio, :falling)

    play_song()
    {:ok, %{reset_gpio: reset_gpio}}
  end

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

  defp set_playing(value), do: GenServer.cast(__MODULE__, {:set_playing, value})

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

  defp play_note(" "), do: Process.sleep(@interval * 3)
  defp play_note(note) do
    Pigpiox.Pwm.hardware_pwm(buzzer_gpio(), Map.get(@notes, note, 0), 500_000) # On
    Process.sleep(@interval * 3)
    Pigpiox.Pwm.hardware_pwm(buzzer_gpio(), Map.get(@notes, note, 0), 0) # Off
    Process.sleep(@interval)
  end

  defp buzzer_gpio(), do: Application.get_env(:circuit2a, :buzzer_gpio)
  defp reset_gpio(), do: Application.get_env(:circuit2a, :reset_gpio)

end
