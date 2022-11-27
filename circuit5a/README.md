# Circuit 5a - Motor

## Overview

In [Circuit 5A](./base), you'll control a simple motor using the Raspberry Pi and the TB6612FNG motor driver.

## Challenges

There are no challenge implementations for this circuit as they don't diverge from the base logic enough to warrant including.

## Hardware

In order to complete these circuits, you'll need the following:

- 1 x Breadboard
- 1 x TB6612FNG Motor Driver
- 1 x DG01D Motor (+ Wheel)
- 1 x External Battery Pack
- 1 x SPST switch
- 6 x M-F Jumper cables
- 5 x M-M Jumper cables

## New Concepts

### TB6612FNG Motor Driver

The TB6612FNG allows for the control of two DC Motors at a peak output of 3.2A.  It has three inputs per motor - two GPIO to control direction and one PWM to control speed.  In addition to speed/direction, the motor supports both stopping (disabling output but allowing the motor to continue turning using it's inertia) and braking (stopping the motor from turning).

### DC Motor

A [direct-current (DC) motor](https://en.wikipedia.org/wiki/DC_motor) converts direct energy into mechanical energy.  DC Motors have gearing that allows them to perform specific tasks - such as having high torque for moving objects or spinning quickly to turn a fan or a wheel.

