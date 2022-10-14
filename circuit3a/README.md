# Circuit 3A - Servo

## Overview

In [Circuit 3A](./base), you'll control a servo using a potentiometer and ADC.

## Challenges

There are no challenge implementations for this circuit as they don't diverge from the base logic enough to warrant including.

## Hardware

In order to complete these circuits, you'll need the following:

- 1 x Breadboard
- 7 x M-F Jumper cables
- 6 x M-M Jumper cables
- 1 x Microservo
- 1 x Analog Potentiometer
- 1 x ADC1115 Analog-to-Digital Converter

## New Concepts

### Servo

A [Servo](https://en.wikipedia.org/wiki/Servomotor) is a motor that can be moved to a precise position.  There are a number of types, but the kind we are working with here have a very specific range of motion.

Like we did with RGB LED control in earlier circuits, we use PWM to control the servo.  By spending different PWM pulses, we tell the servo to move to different positions.
