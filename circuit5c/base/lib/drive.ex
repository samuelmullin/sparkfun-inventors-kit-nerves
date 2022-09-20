defmodule Circuit5c.Drive do
  use GenServer

  alias Circuits.GPIO
  alias TB6612FNG.Module
  alias Circuit5c.HCSR04
  require Logger

  @min_distance 10 #cmhcsr04_ref

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # --- Callbacks ---
  @impl true
  def init(_) do
    switch_pin = Application.get_env(:circuit5c, :switch_pin)
    {:ok, switch_ref} = GPIO.open(switch_pin, :input)
    GPIO.set_interrupts(switch_ref, :both)

    case GPIO.read(switch_ref) do
      1 -> Module.disable_standby(:tb6612fng_module_1)
      0 -> Module.enable_standby(:tb6612fng_module_1)
    end

    hcsr04_config = Application.fetch_env!(:circuit5c, :hcsr04)
    {:ok, hcsr04_ref} = HCSR04.start_link({hcsr04_config.echo, hcsr04_config.trigger})

    Task.async(fn -> drive_loop(hcsr04_ref) end)

    {:ok, %{switch_ref: switch_ref}}
  end

  @impl true
  def handle_info({:circuits_gpio, _, _, 1}, state) do
    Logger.info("disable standby")
    Module.disable_standby(:tb6612fng_module_1)
    {:noreply, state}
  end

  @impl true
  def handle_info({:circuits_gpio, _, _, 0}, state) do
    Logger.info("enable standby")
    Module.enable_standby(:tb6612fng_module_1)
    {:noreply, state}
  end

  # --- Private Implementation ---

  defp drive_loop(hcsr04_ref) do
    get_distance(hcsr04_ref)
    |> move(hcsr04_ref)

    :timer.sleep(100)
    drive_loop(hcsr04_ref)
  end


  def move(distance, hcsr04_ref) when distance < @min_distance do
    move_back_and_left(distance, hcsr04_ref)
  end

  def move(_distance, _hcsr04_ref) do
    move_forwards()
  end

  defp move_forwards() do
    Module.set_output(:tb6612fng_module_1_motor_a, :cw, 500_000)
    Module.set_output(:tb6612fng_module_1_motor_b, :cw, 500_000)
  end

  defp move_back_and_left(distance, hcsr04_ref) when distance < @min_distance * 2 do
    # Keep moving back until we are greater than @min_distance
    Module.set_output(:tb6612fng_module_1_motor_a, :ccw, 500_000)
    Module.set_output(:tb6612fng_module_1_motor_b, :ccw, 500_000)
    :timer.sleep(100)

    get_distance(hcsr04_ref)
    |> move_back_and_left(hcsr04_ref)
  end

  defp move_back_and_left(_distance, _hcsr04_ref) do
    # Turn to the left for 750ms
    Module.set_output(:tb6612fng_module_1_motor_a, :cw, 100_000)
    Module.set_output(:tb6612fng_module_1_motor_b, :ccw, 500_000)
    :timer.sleep(750)
  end

  defp get_distance(hcsr04_ref) do
    with :ok          <- HCSR04.update(hcsr04_ref),
      {:ok, distance} <- HCSR04.info(hcsr04_ref)
    do
      Logger.info("Distance: #{distance}")
      distance
    else
      {:error, code} ->
        Logger.error("Error received when obtaining HCSR04 Reading: #{code}")
        -1
    end
  end

  end
