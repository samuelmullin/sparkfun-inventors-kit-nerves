# Circuit 1A

## Overview

For this challenge, the GenServer is extended to allow for customization of the blink interval.  This includes exposing a public API that allows the user to update a value in the state of the GenServer.  That value is used instead of the module attribute the original circuit used.  There are no changes to the hardware of the circuit.

## Usage

After [creating and uploading the firmware](../../FIRMWARE.md), ssh into the device and use the public API to change the blink_ms value.

```bash
ssh nerves.local
iex(1)> Circuit1a.Blink.change_blink_ms(100)
```

The LED should begin to blink much faster, and you should see a return value in your console of `{:ok, 100}`

If the LED does not blink as expected, refer to the [Troubleshooting Guide](../../TROUBLESHOOTING.md)


## Hardware

There are no changes to the hardware from the [base circuit](../base/README.md#hardware)

## Wiring

There are no changes to the wiring from the [base circuit](../base/README.md#wiring)

## Application Definition & Dependencies

There are no changs to the Application Definiton & Dependencies from the [base circuit](../base/README.md#application-definition--dependencies)

## Config

The [config](./config/config.exs) for this version of the circuit was updated to include a `blink_default_ms` with a value of 500.

```Elixir
config :circuit1a,
  blink_output_gpio: 26,
  blink_default_ms: 500
```


## Supervision

There are no changes to the Supervision from the [base circuit](../base/README.md#supervision)


## Application Logic

The application logic for this circuit is contained in the [Circuit1a.Blink module](./lib/blink.ex).

```elixir

  def change_blink_ms(new_ms) when is_integer(new_ms) do
    GenServer.cast(__MODULE__, {:change_blink_ms, new_ms})
    {:ok, new_ms}
  end

  def change_blink_ms(value) do
    Logger.error("Expected integer, received #{inspect value}")
    {:error, :invalid_integer}
  end
```

In order to support the requirement to change the cadence of the LED blinks, a public API has been added.  `change_blink_ms/1` accepts an integer, and then updates the `blink_ms` value in the GenServer state with that new value via [GenServer.cast/2](https://hexdocs.pm/elixir/1.13/GenServer.html#cast/2).  It returns {:ok, new_ms}.

If a non-integer value is provided, it returns {:error, invalid integer} instead.


```elixir
  @impl true
  def handle_cast({:change_blink_ms, new_ms}, state) do
    {:noreply, Map.merge(state, %{blink_ms: new_ms})}
  end
```

This is the callback to update the blink_ms value.  It waits for a cast with a tuple `{:change_blink_ms, some_int_value}`, then returns a tuple with `:noreply` and the updated state.

```elixir
defp blink_default_ms, do: Application.get_env(:circuit1a, :blink_default_ms)
```

The only change to the private implementation is an extra function to pull the `:default_blink_ms` value out of the `:circuit1a` config.
