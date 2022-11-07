defmodule Circuit3c.Alarm do
  use GenServer

  require Logger
  alias Circuit3c.HCSR04
  alias Circuits.GPIO

  @buzzer_gpio       Application.compile_env!(:circuit3c, :buzzer_gpio)
  @led_gpios         Application.compile_env!(:circuit3c, :led_gpios)
  @servo_gpio        Application.compile_env!(:circuit3c, :servo_gpio)
  @servo_range       Application.compile_env!(:circuit3c, :servo_range)
  @hcrs04            Application.compile_env!(:circuit3c, :hcrs04)

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # --- Callbacks ---
  @impl true
  def init(_) do
    # Get our HCSR04 config and start the HCSR04 GenServer
    hcsr04_config = Application.fetch_env!(:circuit3c, :hcsr04)
    {:ok, hcsr04_ref} = HCSR04.start_link({hcsr04_config.echo, hcsr04_config.trigger})

    # Open LED GPIOs and store references
    {:ok, red_ref} = GPIO.open(@led_gpios.red, :output)
    {:ok, green_ref} = GPIO.open(@led_gpios.green, :output)
    {:ok, blue_ref} = GPIO.open(@led_gpios.blue, :output)

    state = %{
      red_ref: red_ref,
      green_ref: green_ref,
      blue_ref: blue_ref,
      hcsr04_ref: hcsr04_ref
    }


    # Kick off recursive task to light our LED
    Task.async(fn -> alarm_loop(state) end)


    # Store our references in state so they don't get garbage collected
    {:ok, state}
  end

  # Private Implementation
  defp alarm_loop(refs) do
    with :ok             <- HCSR04.update(refs.hcsr04_ref),
         {:ok, distance} <- HCSR04.info(refs.hcsr04_ref)
      do
        check_alarm(distance, refs)
      else
        {:error, code} ->
          Logger.error("Error received when obtaining HCSR04 Reading: #{code}")
      end
    :timer.sleep(100)
    alarm_loop(refs)
  end

  # <25 CM, Light LED Red, Servo to Max, Buzzer
  defp check_alarm(distance, refs) when distance < 10 do
    {_servo_min, servo_max} = @servo_range
    GPIO.write(refs.red_ref, 1)
    GPIO.write(refs.green_ref, 0)
    GPIO.write(refs.blue_ref, 0)
    Pigpiox.Pwm.hardware_pwm(@buzzer_gpio, 800, 500_000)
    Pigpiox.GPIO.set_servo_pulsewidth(@servo_gpio, servo_max)
  end
  # <50cm, Light LED Yellow
  defp check_alarm(distance, refs) when distance < 50 do
    {servo_min, _servo_max} = @servo_range
    GPIO.write(refs.red_ref,  1)
    GPIO.write(refs.green_ref,1)
    GPIO.write(refs.blue_ref, 0)
    Pigpiox.Pwm.hardware_pwm(@buzzer_gpio, 0, 0)
    Pigpiox.GPIO.set_servo_pulsewidth(@servo_gpio, servo_min)

  end
  # >50cm, Light LED Green
  defp check_alarm(_distance, refs) do
    {servo_min, _servo_max} = @servo_range
    GPIO.write(refs.red_ref, 0)
    GPIO.write(refs.green_ref, 1)
    GPIO.write(refs.blue_ref, 0)
    Pigpiox.Pwm.hardware_pwm(@buzzer_gpio, 0, 0)
    Pigpiox.GPIO.set_servo_pulsewidth(@servo_gpio, servo_min)
  end

end
