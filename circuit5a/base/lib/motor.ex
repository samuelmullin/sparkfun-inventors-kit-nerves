defmodule Circuit5a.Motor do
  use GenServer

  alias Circuits.GPIO
  alias TB6612FNG.Module

  @default_speed 250_000

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def set_speed(speed) when speed >= 0 and speed <= 1_000_000 do
    GenServer.cast(__MODULE__, {:set_speed, speed})
  end

  # --- Callbacks ---
  @impl true
  def init(_) do
    switch_pin = Application.fetch_env!(:circuit5a, :switch_pin)
    motor_a_name = Application.fetch_env!(:circuit5a, :tb6612_config)
    |> get_in([:motor_a, :name])

    {:ok, switch_ref} = GPIO.open(switch_pin, :input)
    GPIO.set_interrupts(switch_ref, :both)

    {:ok, %{switch_ref: switch_ref, motor_a_name: motor_a_name, enabled: false, speed: @default_speed}}
  end

  @impl true
  def handle_cast({:set_speed, speed}, %{enabled: true} = state) do
    Module.set_output(state.motor_a_name, :cw, speed)
    {:noreply, Map.put(state, :speed, speed)}
  end

  @impl true
  def handle_cast({:set_speed, speed}, %{enabled: false} = state) do
    {:noreply, Map.put(state, :speed, speed)}
  end

  @impl true
  def handle_info({:circuits_gpio, _, _, 1}, %{speed: speed} = state) do
    Module.set_output(state.motor_a_name, :cw, speed)
    {:noreply, Map.put(state, :enabled, true)}
  end

  @impl true
  def handle_info({:circuits_gpio, _, _, 0}, state) do
    Module.set_output(state.motor_a_name, :cw, 0)
    {:noreply, state |> Map.put(:enabled, false)}
  end

end
