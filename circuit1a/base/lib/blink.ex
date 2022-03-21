defmodule Circuit1a.Blink do
  @moduledoc """
    This is Circuit 1a (Blinking an LED) from the Sparkfun Inventors Kit written
    in elixir.  Upon starting, it blinks an LED at a cadence of 500ms.  It has no
    public API.
  """
  use GenServer

  require Logger
  alias Circuits.GPIO

  @blink_ms 500

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # --- Callbacks ---
  @impl true
  def init(_) do
    {:ok, output_gpio} = GPIO.open(output_gpio(), :output)
    Process.send_after(self(), {:led_on}, 100)
    {:ok, %{output_gpio: output_gpio}}
  end

  @impl true
  def handle_info({:led_on}, %{output_gpio: output_gpio}  = state) do
    led_on(output_gpio, @blink_ms)
    {:noreply, state}
  end

  @impl true
  def handle_info({:led_off}, %{output_gpio: output_gpio}  = state) do
    led_off(output_gpio, @blink_ms)
    {:noreply, state}
  end

  # --- Private Implementation ---
  defp led_on(output_gpio, blink_ms) do
    GPIO.write(output_gpio, 1)
    Process.send_after(self(), {:led_off}, blink_ms)
  end

  defp led_off(output_gpio, blink_ms) do
    GPIO.write(output_gpio, 0)
    Process.send_after(self(), {:led_on}, blink_ms)
  end

  defp output_gpio, do: Application.get_env(:circuit1a, :blink_output_gpio)

end
