defmodule Circuit5b.Drive do
  use GenServer

  alias Circuits.GPIO
  alias TB6612FNG.Module

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # --- Callbacks ---
  @impl true
  def init(_) do
    switch_pin = Application.get_env(:circuit5b, :switch_pin)
    {:ok, switch_ref} = GPIO.open(switch_pin, :input)
    GPIO.set_interrupts(switch_ref, :both)
    {:ok, %{switch_ref: switch_ref}}
  end

  @impl true
  def handle_info({:circuits_gpio, _, _, 1}, state) do
    Module.set_output(:motor_a, :cw, 250_000)
    Module.set_output(:motor_b, :cw, 250_000)
    {:noreply, state}
  end

  @impl true
  def handle_info({:circuits_gpio, _, _, 0}, state) do
    Module.set_output(:motor_a, :cw, 0)
    Module.set_output(:motor_b, :cw, 0)
    {:noreply, state}
  end

end
