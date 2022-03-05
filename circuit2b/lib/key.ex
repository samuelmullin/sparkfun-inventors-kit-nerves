defmodule Circuit2b.Key do
  use GenServer

  require Logger
  alias Circuits.GPIO

  @default_volume 500_000 # 50%
  @buzzer_pin 13


  def start_link([name: name, pin: pin, frequency: frequency]) do
    GenServer.start_link(__MODULE__, %{pin: pin, frequency: frequency}, name: name)
  end

  # Callbacks
  @impl true
  def init(%{pin: pin, frequency: frequency}) do
    {:ok, gpio} = GPIO.open(pin, :input)
    Circuits.GPIO.set_pull_mode(gpio, :pullup)
    Circuits.GPIO.set_interrupts(gpio, :both)
    {:ok, %{pin: pin, frequency: frequency, gpio: gpio}}
  end


  @impl true
  def handle_info({:circuits_gpio, _pin, _timestamp, 1}, state) do
    Pigpiox.Pwm.hardware_pwm(@buzzer_pin, 0, 0)
    {:noreply, state}
  end

  @impl true
  def handle_info({:circuits_gpio, _pin, _timestamp, 0}, %{frequency: frequency} = state) do
    Pigpiox.Pwm.hardware_pwm(@buzzer_pin, frequency, @default_volume)
    {:noreply, state}
  end

end
