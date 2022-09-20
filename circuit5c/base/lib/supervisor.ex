defmodule Circuit5c.Supervisor do

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      Circuit5c.Drive,
      {TB6612FNG, [
        standby_pin: 21,
        motor_a: [
          pwm_pin: 12,
          in01_pin: 20,
          in02_pin: 16,
          name: :tb6612fng_module_1_motor_a
        ],
        motor_b: [
          pwm_pin: 13,
          in01_pin: 5,
          in02_pin: 6,
          name: :tb6612fng_module_1_motor_b
        ],
        name: :tb6612fng_module_1
      ]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end


end
