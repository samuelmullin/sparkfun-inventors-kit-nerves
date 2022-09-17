defmodule Circuit4c.Supervisor do

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      Circuit4c.WhoAmI
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end


end
