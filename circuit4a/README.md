# Circuit 1D - RGB LED

## Overview

In [Circuit 1D](./base), you'll control an RGB LED using a photoresistor, potentiometer, ADC and PWM controller.  The breadboard is going to be a mess so be careful with those connections!

## Challenges

There are no challenge implementations for this circuit as they don't diverge from the base logic enough to warrant including.

## Hardware

In order to complete these circuits, you'll need the following:

- 1 x Breadboard
- 1 x RGB LED
- 3 x 330ohm Resistor
- 7 x M-F Jumper cables
- 6 x M-M Jumper cables
- 1 x Analog Potentiometer
- 1 x Analog Photoresistor
- 1 x ADC1115 Analog-to-Digital Converter

## New Concepts

### Pulse Width Modulation (PWM)

[PWM](https://en.wikipedia.org/wiki/Pulse-width_modulation) switches a circuit on and off an an incredibly high frequency in order to provide it with a lower percentage of total power.  For an LED, this allows us to do things such as increase or decrease the brightness.  It's also commonly used for things like motors or servos to limit the speed of the device.

The Raspberry Pi can do software PWM on any of its pins, but it has four pins that are dedicated to PWM, separated into two channels (gpios 12 and 18) and (gpios 13 and 19).