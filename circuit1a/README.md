# Circuit 1A - Blinking an LED

## Overview

In [Circuit 1A](./base), you'll learn how to use Nerves and the circuits_gpio library to blink an LED by turning one of our GPIO pins on and off at a regular cadence.

## Challenges

If you're interested in seeing example solutions to the challenges for this circuit, you can find them here:

[Blink](./blink) extends our base circuit by adding a public API that we can use to change the cadence of the blink
[Morse](./morse) exposes a public API that allows us to blink morse code messages via our LED

## Hardware

In order to complete these circuits, you'll need the following:

- 1 x Breadboard
- 1 x LED - Colour doesn't really matter here, but we don't want RGB
- 1 x 330ohm Resistor
- 2 x Jumper cables

## New Concepts

### Breadboard

[Breadboards](https://en.wikipedia.org/wiki/Breadboard) are used frequently in Electronics projects, particularly for learning and quick prototyping. Because they are reusable and solderless, it's very easy to use them to test an idea or understand a new component.  We'll use our solderless breadboard for every circuit.

### Light Emitting Diode (LED)

An [LED](https://en.wikipedia.org/wiki/Light-emitting_diode) is a light made from a silicon diode.   They come in many shapes and colours and are usually used to represent some internal state for the user.  One my my earliest LED memories was the little red LED in my Nintendo Entertainment System.  When the system was on it was solid red - but every once in a while when it couldn't read a cartridge, it would blink.  That was our cue to blow inside the cartridge!

A basic LED has two legs of different lengths to show us which side is positive and which is negative.  The positive leg is a bit longer and is called the cathode.  The shorter, negative leg is called the annode.  If you pass the right amount of current through the LED from the positive side to the negative side, it will light up.  If you pass too much it will burn out, though, so you should always use a resistor in line to ensure that doesn't happen.

### Resistor

There are many kinds of [resistors](https://en.wikipedia.org/wiki/Resistor) but the most common ones, like the ones in the kit, are axial carbon film.  They have a number of coloured bands on the outside of them that represent the amount of resistance they provide.  If you have gotten yours mixed up, you can reference a [resistor chart] to figure out what the resistance of a particular one happens to be.

Because all of the circuits in the kit are wired in series, it doesn't matter where the resistor is placed.  In most cases where you have a polarized element in your circuit (such as an LED), you'll place it on the negative side out of convenience, using it to bridge between the row the LED is placed in and the ground.

### Jumper Cable

Jumper cables are small wires used to connect things to our breadboard.  Jumper cables come in different configurations, you'll need a mix of male/male and male/female to complete all the circuits in the kit.

### Elixir GenServer

A simple way to think about a [GenServer](https://hexdocs.pm/elixir/main/GenServer.html) is as a FIFO mailbox.  It receives messages, and when you create a GenServer you define how the GenServer should handle the messages you're expecting by providing a set of callbacks to cover each case.  A typical callback looks like this:

```Elixir
  @impl true
  def handle_info(:led_on, %{output_gpio: output_gpio}  = state) do
    led_on(output_gpio, @blink_ms)
    {:noreply, state}
  end
```

Let's break this down!

`@impl true` tells Elixir that this is part of the expected GenServer behaviour.  This allows the compiler to warn us if it doesn't conform to what GenServer is expecting.

`def handle_info({:led_on}, %{output_gpio: output_gpio}  = state) do` is our function signature.  The function expects to receive two variables - the first is an atom: `:led_on`, the second is a map that contains the key `:output_gpio`.  This code will only be executed if this specific message is received.

`led_on(output_gpio, @blink_ms)`  is calling another _private_ function (`led_on`) with output_gpio value and `@blink_ms`, which is a module level attribute (denoted by the `@`).

`{:noreply, state}` is our return value.  For these message handling callbacks, they are always a tuple where the first value is either `:reply` if the request is synchronous and `:noreply` if it's asyncronous.

`end` denotes that the function is complete

Typically, a process outside the GenServer isn't sending messages directly.  Instead, the GenServer will have a public API that is exposed for other modules to interact with it.  In each of our circuit implementations, the GenServer code will be broken down into `Public API`, `Callbacks` and `Private Implementation`.

There are three separate behaviours we may need to implement, depending on our requirements for a given circuit:

  `handle_cast(message, state)` - is an asyncronous call.  It will execute some logic, possibly mutate the state, and then send back {:noreply, state}.  You can use this for fire-and-forget actions where you don't need to wait for the call to complete before you move on.

  `handle_call(message, from_pid, state)` - is a synchronous call.  It will execute some logic, possibly mutate the state, then send back {:reply, some_value, state}.  When working with circuits, you typically use this when you need to make sure some action completed before performing our next action.

  `handle_info(message, state)` - is is an asynchronous call.  It will execute some logic, possibly mutate the state, then send back {:noreply, state}.  While you can cast/call directly ([GenServer.cast/2](https://hexdocs.pm/elixir/main/GenServer.html#cast/2), [GenServer.call/3](https://hexdocs.pm/elixir/main/GenServer.html#call/3)), info messages typically come from things like [Process.send_after/4](https://hexdocs.pm/elixir/main/Process.html#send_after/4), which you will use in this circuit for blinking LEDS.




