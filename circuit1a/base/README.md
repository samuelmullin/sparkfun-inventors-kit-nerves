# Circuit 1A

## Overview

This circuit implements a simple GenServer to blink an LED at a cadence of 500ms.

## Usage

After [creating and uploading the firmware](../../FIRMWARE.md), and after a startup time of 30s or so, the LED should blink at a cadence of 500ms.

If the LED does not blink as expected, refer to the [Troubleshooting Guide](../../TROUBLESHOOTING.md)

## Hardware

In order to complete this circuit, you'll need the following:

- 1 x Breadboard
- 1 x LED - Colour doesn't really matter here, but not RGB
- 1 x 330ohm Resistor
- 2 x Jumper cables


## Wiring

[Need a diagram or a picture here]

Bridge the left and right side of the breadboard with your LED.  The cathode should be on the right side.  Connect the left side of the breadboard to the ground rail on the left side of the breadboard.

Connect any ground on the raspberry pi to the ground rail on the right hand side.  Connect GPIO 26 to the same row as the cathode.

## Application Definition & Dependencies

The application is defined in  in the [mix.exs file](./mix.exs). This contains a lot of boilerplate, but here are some important sections:

```elixir
def application do
[
    mod: {Circuit1a, []},
    extra_applications: [:logger, :runtime_tools]
]
end
```

The `application/0` method tells Elixir what modules/applications should start when this application is started.  The mod attribute in this case contains a tuple that says `Start the Circuit1a module with an empty list of arguments`.  Extra applications says `when this application is started, also start the :logger and :runtime_tools applications`

```elixir
defp deps do
[
    # Dependencies for all targets
    {:nerves, "~> 1.7.15", runtime: false},
    {:shoehorn, "~> 0.8.0"},
    {:ring_logger, "~> 0.8.3"},
    {:toolshed, "~> 0.2.13"},
    {:circuits_gpio, "~> 0.4"},
    # ...
]
  end
```

The `deps/0` method defines a list of dependencies for this application so mix knows what needs to be installed for it to function.  `Circuit1a` includes one dependency that was not part of the nerves boilerplate: [{:circuits_gpio, "~> 0.4"}](https://github.com/elixir-circuits/circuits_gpio), which is used to interact with the GPIO pins on our target device.


## Config

The [config](./config/config.exs) for this version of the circuit is simple:

```Elixir
config :circuit1a,
  blink_output_gpio: 26
```

For things like GPIO values, it's tempting to just use module attributes, but getting used to using the config files now will benefit us later when our config will include more values.  It's helpful to be consistent as well.

If you do decide to hardcode things like GPIO numbers, you can use [module attributes](https://elixir-lang.org/getting-started/module-attributes.html)


## Supervision

The [supervisor](./lib/supervisor.ex) is simple as well.  There's a single child process starting (Circuit1a.Blink), and it specifies a `:one_for_one` strategy, which means if the child process dies, the supervisor will start a new one. 

Since this is the first supervisor, let's take a closer look.  

```elixir
use Supervisor
```

Invoking [use](https://elixir-lang.org/getting-started/alias-require-and-import.html#use) tells Elixir that this module is extending the [Supervisor](https://elixir-lang.org/getting-started/mix-otp/supervisor-and-application.html) module.  A supervisor is responsible for monitoring child processes.



```elixir
def start_link(opts) do
  Supervisor.start_link(__MODULE__, :ok, opts)
end
```

`start_link/3` is defining what should happen when this module is started.  In this case, it's deferring to [Supervisor.start_link/3](https://hexdocs.pm/elixir/1.12/Supervisor.html#start_link/3)

```elixir
@impl true
def init(:ok) do
children = [
    Circuit1a.Blink
]

Supervisor.init(children, strategy: :one_for_one)
end
```

`init/1` is defining the list of children and the strategy that should be applied for managing them.  In this case, there is only one child, the module [Circuit1a.Blink](./lib/blink.ex)


## Application Logic

The application logic for this circuit is contained in the [Circuit1a.Blink module](./lib/blink.ex).

```elixir
defmodule Circuit1a.Blink do
  @moduledoc """
    This is Circuit 1a (Blinking an LED) from the Sparkfun Inventors Kit written
    in elixir.  Upon starting, it blinks an LED at a cadence of 500ms.  It has no
    public API.
  """
  use GenServer

  require Logger
  alias Circuits.GPIO

  @blink_ms 500

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end
```

The first block defines the module and tells Elixir that it will be extending [GenServer](https://hexdocs.pm/elixir/GenServer.html).  It requires Logger, and has an alias to the Circuits.GPIO module.  More info on require, alias and import is available in the [Elixir Docs](https://elixir-lang.org/getting-started/alias-require-and-import.html).  For now it's enough to understand that we can access the Logger module and the GPIO module directly after doing this.

This block also defines a [module attribute](https://elixir-lang.org/getting-started/module-attributes.html) called `@blink_ms` with a value of 500.  This is not configurable and will be used as the interval for blinking the LED.

Finally, this block also defines the `start_link/1` method that is required when extending GenServer.  It starts a GenServer using this module with the name of this module.  This is a common pattern when the expectation is there will only be single instance of this module in a given supervision tree.


```elixir
  # --- Callbacks ---
  @impl true
  def init(_) do
    {:ok, output_gpio} = GPIO.open(output_gpio(), :output)
    Process.send_after(self(), :led_on, 100)
    {:ok, %{output_gpio: output_gpio}}
  end

  @impl true
  def handle_info(:led_on, %{output_gpio: output_gpio}  = state) do
    led_on(output_gpio, @blink_ms)
    {:noreply, state}
  end

  @impl true
  def handle_info(:led_off, %{output_gpio: output_gpio}  = state) do
    led_off(output_gpio, @blink_ms)
    {:noreply, state}
  end
```

The next block describes the callbacks for this GenServer - what it should do when it starts up, and what type of messages it expects to receive, along with any logic required for handlng those messages.  It's important to note that if a GenServer receives a message that does not match one of these patterns, it will crash.

`init/1` Defines what should happen when the genserver starts up.  It opens the gpio defined in our config, which we access via `output_gpio/0` (more on that later in the private implementation).  Opening the gpio means using the [open/2]() method from the GPIO module to get a reference.  *It's very important to store that reference in the state for the GenServer*, otherwise it will get garbage collected and you will stop receiving messages.


`handle_info/2` has two definitions - one in which it receives an `:led_on` and one in which it receives an `:led_off`.  Each of these pulls the GPIO reference out of the state, passes it to a private method to take some action, then returns {:noreply, state}.

It's important to note what doesn't matter in this case is where these messages are coming from - the GenServer only cares about the contents of the message in this case.

```elixir
 # --- Private Implementation ---
  defp led_on(output_gpio, blink_ms) do
    GPIO.write(output_gpio, 1)
    Process.send_after(self(), :led_off, blink_ms)
  end

  defp led_off(output_gpio, blink_ms) do
    GPIO.write(output_gpio, 0)
    Process.send_after(self(), :led_on, blink_ms)
  end

  defp output_gpio, do: Application.get_env(:circuit1a, :blink_output_gpio)

end
```

The last section is the private implementation.  Most of the application logic should live here, hidden from the end user.  Since it's private, there's no implicit contract with the user and it can be changed as often as is necessary.


`led_on/2` Accepts an output GPIO and a duration.  It sets the value of that GPIO to 1, then sends a new info message (:led_off) with a delay of blink_ms. 

`led_off/2` Accepts an output GPIO and a duration.  It sets the value of that GPIO to 0, then sends a new info message (:led_on) with a delay of blink_ms.

`output_gpio/0` Uses [Application.get_env/3](https://hexdocs.pm/elixir/1.12/Application.html#get_env/3) to fetch the `:blink_output_gpio` value from our `:circuit1a` config stanza.  If it doesn't find a value, it will implicitly set it to `nil`.
