defmodule Circuit1b.Supervisor do

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      Circuit1b.Potentiometer
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end


end
