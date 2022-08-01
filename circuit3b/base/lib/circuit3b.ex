defmodule Circuit3b do
  use Application

  @impl true
  def start(_type, _args) do
    # Although we don't use the supervisor name below directly,
    # it can be useful when debugging or introspecting the system.
    Circuit3b.Supervisor.start_link(name: Circuit3b.Supervisor)
  end
end
