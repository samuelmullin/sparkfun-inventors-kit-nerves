# Circuit 1A

## Overview

Circuit 1A is focused on blinking an LED, and will serve as a sort of "hello world" project as we learn about building circuits with the Raspberry Pi and Nerves.

For the included code to work, you will need the following:

1 x Breadboard
2 x LED - Colour doesn't really matter here, but we don't want RGB
2 x 330ohm Resistor
3 x Jumper cables

Keep in mind that the longer leg of an LED is the cathode and is the positive side, which means we'll connect it to our GPIO.  The shorter leg is the annode and is the negative side.  On the far side of the annode, between the LED and the ground, we put our resistors.  The resistors can go on either side of the LED, but I've always put them on the ground side.

Our connections look like this:

We setup our LEDs bridging the left and right sides of the breadboard.  The cathode is on the right side and the annode is on the left.  On the right side, we connect our GPIOs using jumpers.  One LED is connected to GPIO 26.  The other is connected to GPIO 19.  On the right side, we use our 330ohm resistor to bridge to the GND rail, and we connect the GND on the pi to the GND rail as well.

We then set our [target](https://hexdocs.pm/nerves/targets.html#content) - for me, this is:
`MIX_TARGET=rpi0`

We can then create our firmware:
`mix firmware`

At this point we plug in our device (with the SD card inserted).  Make sure you connect the pi via a port that can supply both data and power - in the case of the PI Zero, we connect to the left USB port as the right only supplies power.

Now, let's upload our firmware:
`mix upload`

After 30 seconds or so, you should see the LED connected via GPIO 26 start blinking.  We can now connect to the running device to execute commands using our API:

`mix ssh nerves.local`

## Circuit 1A Api

Our Circuit1A app will serve as the framework we'll use to build our subsequent circuits, so we'll cover the moving parts in a bit more detail.

In our (mix.exs)[./mix.exs] we specify a `mod` for our `application` - this tells Elixir which module should start when we start the application.  In our case, we are going to start the module Circuit1a. In turn, Circuit1a will start a [Supervisor](./lib/supervisor.ex) which will then kick off two child processes, [blink](./lib/blink.ex) and [morse](./lib/morse.ex), each of which consists of a [GenServer](https://hexdocs.pm/elixir/1.12/GenServer.html) with a publically available API. 

When we ssh into our device with the application running, we get an interactive elixir shell that we can use to interact with the Public API for the blink and morse modules.

### Blink

On startup, the Blink module kicks off a loop that blinks our LED with a base time unit of 500ms - that is, it turns the light on for 500ms, then off for 500ms.  This was the basic circuit required for Circuit1A.  As part of the challenges, we have also exposed a function (Circuit1a.Blink.change_blink_ms/1)[] that accepts an integer value that represents the new base time unit for the blink cycle.

### Morse

The Morse module tackles another challenge for Circuit1a.  On startup, it initializes our GPIO pin and then waits for the user to send a message via (Circuit1a.Morse.blink_morse/1)[].  When it receives a string via this function, it downcases the string, splits it into characters and then creates a list of values (dots, dashes and pauses) which it then feeds through into an algorithm that blinks the connected LED appropriately.
