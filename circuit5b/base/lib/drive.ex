defmodule Circuit5b.Drive do
  use GenServer

  alias Circuits.GPIO
  alias TB6612FNG.Module

  @default_speed 250_000
  @directions [:forward, :backward, :left, :right]

  # --- Public API ---

  def set_speed(speed) when speed >= 0 and speed <= 1_000_000 do
    GenServer.cast(__MODULE__, {:set_speed, speed})
    {:ok, speed}
  end

  def set_speed(_) do
    {:error, "Speed must be between 0 and 1_000_000"}
  end

  def command(direction, time) when direction in @directions and is_integer(time) do
    GenServer.cast(__MODULE__, {:drive, :direction, :time})
  end

  def command(direction, _) do
    {:error, "Invalid direction: #{direction}.  Direction must be one of: #{inspect(directions)}"}

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # --- Callbacks ---
  @impl true
  def init(_) do
    switch_pin = Application.get_env(:circuit5b, :switch_pin)
    tb6612_config = Application.fetch_env!(:circuit5b, :tb6612_config)

    {:ok, switch_ref} = GPIO.open(switch_pin, :input)
    GPIO.set_interrupts(switch_ref, :both)

    state = %{
      switch_ref: switch_ref,
      motor_a_name: get_in(tb6612_config, [:motor_a, :name]),
      motor_b_name: get_in(tb6612_config, [:motor_b, :name]),
      speed: @default_speed,
      enabled: false
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:set_speed, speed}, state) do
    {:noreply, Map.put(state, :speed, speed)}
  end

  @impl true
  def handle_cast({:drive, _, _}, %{enabled: false} = state) do
    Logger.info("Received drive but motors are disabled")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:drive, :forward, time}, %{speed: speed} = state) do
    Module.set_output(state.motor_a_name, :cw, speed)
    Module.set_output(state.motor_b_name, :cw, speed)
    Process.sleep(time)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:drive, :backward, time}, %{speed: speed} = state) do
    Module.set_output(state.motor_a_name, :ccw, speed)
    Module.set_output(state.motor_b_name, :ccw, speed)
    Process.sleep(time)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:drive, :right, time}, %{speed: speed} = state) do
    Module.set_output(state.motor_a_name, :cw, speed)
    Module.set_output(state.motor_b_name, :ccw, speed)
    Process.sleep(time)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:drive, :left, time}, %{speed: speed} = state) do
    Module.set_output(state.motor_a_name, :ccw, speed)
    Module.set_output(state.motor_b_name, :cw, speed)
    Process.sleep(time)
    {:noreply, state}
  end

  @impl true
  def handle_info({:circuits_gpio, _, _, 1}, state) do
    {:noreply, Map.put(state, :enabled, true)}
  end

  @impl true
  def handle_info({:circuits_gpio, _, _, 0}, state) do
    {:noreply, Map.put(state, :enabled, false)}
  end

end
