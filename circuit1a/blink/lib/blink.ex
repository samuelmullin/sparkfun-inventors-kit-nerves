defmodule Circuit1a.Blink do
    @moduledoc """
    This is an implementation of one of the challenges from Circuit 1a (Blinking an LED)
    of the Sparkfun Inventors Kit.  Upon starting, it blinks an LED at a cadence of 500ms.
    It's API consists of a single endpoint (change_blink_ms/1) which accepts an integer
    value representing the new cadence.
  """
  use GenServer

  require Logger
  alias Circuits.GPIO

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # --- Public API ---

  @doc """
    Accepts an integer and sents an async message to our Genserver updating
    the 'blink_ms' value in its state to the new integer value.  If the value
    provided was valid, returns {:ok, value}.  If the value was invalid it
    returns {:error, :invalid_integer}.
  """
  def change_blink_ms(new_ms) when is_integer(new_ms) do
    GenServer.cast(__MODULE__, {:change_blink_ms, new_ms})
    {:ok, new_ms}
  end

  def change_blink_ms(value) do
    Logger.error("Expected integer, received #{inspect value}")
    {:error, :invalid_integer}
  end

  # --- Callbacks ---

  @impl true
  def init(_) do
    {:ok, output_gpio} = GPIO.open(output_gpio(), :output)
    Process.send_after(self(), :led_on, 100)
    {:ok, %{output_gpio: output_gpio, blink_ms: blink_default_ms()}}
  end

  @impl true
  def handle_cast({:change_blink_ms, new_ms}, state) do
    {:noreply, Map.merge(state, %{blink_ms: new_ms})}
  end

  @impl true
  def handle_info(:led_on, %{output_gpio: output_gpio, blink_ms: blink_ms}  = state) do
    led_on(output_gpio, blink_ms)
    {:noreply, state}
  end

  @impl true
  def handle_info(:led_off, %{output_gpio: output_gpio, blink_ms: blink_ms}  = state) do
    led_off(output_gpio, blink_ms)
    {:noreply, state}
  end

  # --- Private Implementation ---

  defp led_on(output_gpio, blink_ms) do
    GPIO.write(output_gpio, 1)
    Process.send_after(self(), :led_off, blink_ms)
  end

  defp led_off(output_gpio, blink_ms) do
    GPIO.write(output_gpio, 0)
    Process.send_after(self(), :led_on, blink_ms)
  end

  defp output_gpio, do: Application.get_env(:circuit1a, :blink_output_gpio)
  defp blink_default_ms, do: Application.get_env(:circuit1a, :blink_default_ms)

end
