defmodule Circuit5a.Supervisor do

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    tb6612_config = Application.fetch_env!(:circuit5a, :tb6612_config)
    children = [
      Circuit5a.Motor,
      {TB6612FNG, tb6612_config}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end


end
