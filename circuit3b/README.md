# Circuit 3b - RGB Distance Sensor

## Overview

In [Circuit 3b](./base), you'll control an RGB LED based on the input from an ultrasonic distance sensor.

## Challenges

There are no challenge implementations for this circuit as they don't diverge from the base logic enough to warrant including.

## Hardware

In order to complete these circuits, you'll need the following:

- 1 x Breadboard
- 1 x Common Annode RGB LED
- 4 x 330ohm Resistor
- 1 x 470ohm resistor
- 7 x M-F Jumper cables
- 2 x M-M Jumper cables
- 1 x HC-SR04 Ultrasonic Distance Sensor

## New Concepts

### Ultrasonic Distance Sensor (HC-SR04)

An ultrasonic distance sensor such as the [HC-SR04](https://www.sparkfun.com/products/15569) works by sending out a small burst of high frequency sound, then measuring how long it takes to receive that pulse back. Based on the timing, we can infer the approximate distance to an object.  Because the sensor is driven by a 5v signal, we need a voltage divider between the echo pin and our raspberry pi (which uses 3.3v logic)

### Voltage Divider

A [voltage divider](https://en.wikipedia.org/wiki/Voltage_divider) uses two resistors to reduce an output voltage to a fraction of it's input voltage.  They work in the same way that a potentiometer does.  The amount of output we get in the middle of the two resistors is a percentage of the input voltage equal to the fraction represented by the resistors.  Sparkfun has some detailed documentation on the concept [here](https://learn.sparkfun.com/tutorials/voltage-dividers/all)

### Elixir Ports

Elixir has two built in methods for interacting code that is not written in Erlang or Elixir.  One is a NIF, or a Native Implemented Function, and the other is a Port, which basically monitors the STDOUT of another process.

One of the advantages of using a NIF or a Port is the ability to work around definciencies or drawbacks that come along with Elixir and the Beam.  One such drawback is millisecond accuracy - for most purposes, millisecond precision is fine, but the ultrasonic sensor requires we send a pulse with microsecond precision.  

Since we can't implement that in Elixir/Erlang, we use a Port to consume input from a [https://github.com/samuelmullin/nerves_hcsr04](driver written in c). Note that I did not write this library, but I did fork it as it did not work with the latest version of erlang without some minor modifications.