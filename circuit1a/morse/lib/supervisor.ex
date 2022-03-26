defmodule Circuit1a.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      Circuit1a.Morse
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end


end
