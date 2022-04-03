defmodule Circuit1d do
  use Application

  @impl true
  def start(_type, _args) do
    # Although we don't use the supervisor name below directly,
    # it can be useful when debugging or introspecting the system.
    Circuit1d.Supervisor.start_link(name: Circuit1d.Supervisor)
  end
end
