defmodule Circuit3c.Supervisor do

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      Circuit3c.Alarm
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end


end
