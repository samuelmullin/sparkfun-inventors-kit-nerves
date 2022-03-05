defmodule Circuit2a.Music do
  use GenServer

  require Logger

  @pwm_pin 13
  @default_volume 500_000 # 50%
  @notes %{ # common note frequencies
    "c" => 262,
    "d" => 294,
    "e" => 330,
    "f" => 349,
    "g" => 392,
    "a" => 440,
    "b" => 494,
  }
  @interval 100 # default interval in ms
  @default_song "ccdcfe ccdcgf ccdafed bbafgf"

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # Public API
  def play_song(song \\ @default_song) do
    GenServer.cast(__MODULE__, {:play_song, song})
  end

  # Callbacks
  @impl true
  def init(_) do
    play_song()
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:play_song, song}, state) do
    play_song(@pwm_pin, song)
    {:noreply, state}
  end

  # Private Implementation
  defp play_song(pin, song) do
    song
    |> String.downcase()
    |> String.graphemes()
    |> Enum.each(fn note -> play_note(pin, note) end)
  end

  defp play_note(_pin, " "), do: Process.sleep(@interval * 3)
  defp play_note(pin, note) do
    Pigpiox.Pwm.hardware_pwm(@pwm_pin, Map.get(@notes, note), @default_volume) # On
    Process.sleep(@interval * 3)
    Pigpiox.Pwm.hardware_pwm(@pwm_pin, Map.get(@notes, note), 0) # Off
    Process.sleep(@interval)
  end


end
