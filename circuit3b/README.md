# Circuit 3b - RGB Distance Sensor

## Overview

In [Circuit 3b](./base), you'll control an RGB LED based on the input from an ultrasonic distance sensor.

## Challenges

There are no challenge implementations for this circuit as they don't diverge from the base logic enough to warrant including.

## Hardware

In order to complete these circuits, you'll need the following:

- 1 x Breadboard
- 1 x RGB LED
- 3 x 330ohm Resistor
- 7 x M-F Jumper cables
- 6 x M-M Jumper cables
- 1 x HCSR04 Ultraonic Sensor

## New Concepts

### Ultrasonic Distance Sensor (HC-SR04)

An ultrasonic distance sensor such as the [HC-SR04](https://www.sparkfun.com/products/15569) works by sending out a small burst of high frequency sound, then measuring how long it takes to receive that pulse back. Based on the timing, we can infer the approximate distance to an object.

### Elixir Ports

Elixir has two built in methods for interacting code that is not written in Erlang or Elixir.  One is a NIF, or a Native Implemented Function, and the other is a Port, which basically monitors the STDOUT of another process.

One of the advantages of using a NIF or a Port is the ability to work around definciencies or drawbacks that come along with Elixir and the Beam.  One such drawback is millisecond accuracy - for most purposes, millisecond precision is fine, but the ultrasonic sensor requires we send a pulse with microsecond precision.  

Since we can't implement that in Elixir/Erlang, we use a Port to consume input from a [https://github.com/samuelmullin/nerves_hcsr04](driver written in c). Note that I did not write this library, but I did fork it as it did not work with the latest version of erlang without some minor modifications.