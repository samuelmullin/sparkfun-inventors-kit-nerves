defmodule Circuit3b.RGB do
  use GenServer

  require Logger
  alias Circuit3b.HCSR04

  @led_gpios Application.get_env(:circuit3b, :led_gpios)

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # --- Callbacks ---
  @impl true
  def init(_) do
    # Get our HCSR04 config and start the HCSR04 GenServer
    hcsr04_config = Application.fetch_env!(:circuit3b, :hcsr04)
    {:ok, hcsr04_ref} = HCSR04.start_link({hcsr04_config.echo, hcsr04_config.trigger})

    # Kick off recursive task to light our LED
    Task.async(fn -> light_loop(hcsr04_ref) end)

    # Store our references in state so they don't get garbage collected
    {:ok, %{hcsr04_ref: hcsr04_ref}}
  end

  # Private Implementation
  defp light_loop(hcsr04_ref) do
    with :ok             <- HCSR04.update(hcsr04_ref),
         {:ok, distance} <- HCSR04.info(hcsr04_ref)
      do
        light_led(distance)
      else
        {:error, code} ->
          Logger.error("Error received when obtaining HCSR04 Reading: #{code}")
      end
    :timer.sleep(50)
    light_loop(hcsr04_ref)
  end

  # <25 CM, Light LED Red
  defp light_led(distance) when distance < 25 do
    Pigpiox.Pwm.gpio_pwm(@led_gpios.red, 250)
    Pigpiox.Pwm.gpio_pwm(@led_gpios.green, 0)
    Pigpiox.Pwm.gpio_pwm(@led_gpios.blue, 0)
  end
  # <50cm, Light LED Yellow
  defp light_led(distance) when distance < 50 do
    Pigpiox.Pwm.gpio_pwm(@led_gpios.red, 250)
    Pigpiox.Pwm.gpio_pwm(@led_gpios.green, 250)
    Pigpiox.Pwm.gpio_pwm(@led_gpios.blue, 0)
  end
  # >50cm, Light LED Green
  defp light_led(_distance) do
    Pigpiox.Pwm.gpio_pwm(@led_gpios.red, 0)
    Pigpiox.Pwm.gpio_pwm(@led_gpios.green, 250)
    Pigpiox.Pwm.gpio_pwm(@led_gpios.blue, 0)
  end

end
