defmodule Circuit5b.Supervisor do

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      Circuit5b.Drive,
      {TB6612FNG, [
        standby_pin: 21,
        motor_a: [
          pwm_pin: 12,
          in01_pin: 20,
          in02_pin: 16,
          name: :motor_a
        ],
        motor_b: [
          pwm_pin: 13,
          in01_pin: 5,
          in02_pin: 6,
          name: :motor_b
        ]
      ]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end


end
