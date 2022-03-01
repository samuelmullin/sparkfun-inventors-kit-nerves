defmodule Circuit1a.Blink do
  use GenServer

  require Logger
  alias Circuits.GPIO

  @output_pin 26
  @default_blink_ms 500

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # Public API
  def change_blink_ms(new_ms) do
    GenServer.cast(__MODULE__, {:change_blink_ms, new_ms})
  end

  # Callbacks
  @impl true
  def init(_) do
    {:ok, output_gpio} = GPIO.open(@output_pin, :output)
    led_on(output_gpio, @default_blink_ms)
    {:ok, %{output_gpio: output_gpio, blink_ms: @default_blink_ms}}
  end

  @impl true
  def handle_cast({:change_blink_ms, new_ms}, state) do
    {:noreply, Map.merge(state, %{blink_ms: new_ms})}
  end

  # Private Implementation
  @impl true
  def handle_info({:led_on}, %{output_gpio: output_gpio, blink_ms: blink_ms}  = state) do
    led_on(output_gpio, blink_ms)
    {:noreply, state}
  end

  @impl true
  def handle_info({:led_off}, %{output_gpio: output_gpio, blink_ms: blink_ms}  = state) do
    led_off(output_gpio, blink_ms)
    {:noreply, state}
  end

  defp led_on(output_gpio, blink_ms) do
    GPIO.write(output_gpio, 1)
    Process.send_after(self(), {:led_off}, blink_ms)
  end

  defp led_off(output_gpio, blink_ms) do
    GPIO.write(output_gpio, 0)
    Process.send_after(self(), {:led_on}, blink_ms)
  end

end
