# Circuit 4B - Temperature Sensor LCD Display

## Overview

In [Circuit 4B](./base), you'll build on the LCD screen circuit from [Circuit 4A](../circuit4a) by adding an analog temperature sensor and displaying it's output on the LCD.

## Challenges

There are no challenge implementations for this circuit as they don't diverge from the base logic enough to warrant including.

## Hardware

In order to complete these circuits, you'll need the following:

- 1 x Breadboard
- 10 x M-F Jumper cables
- 14 x M-M Jumper cables
- 1 x Analog Potentiometer
- 1 x HD44780 Based 16x2 LCD Screen
- 1 x ADS1115 Analog-to-Digital Converter
- 1 x TMP36 analog temperature sensor


## New Concepts

### TMP36 Temperature Sensor

The [TMP36 analog temperature sensor](https://www.sparkfun.com/products/10988) increases it's resistance based on the temperature it's exposed to.  It has a range of –40°C to +125°C.  Because it's an analog sensor, we need to pair it with an Analog to Digital converter (we'll use the ADS1115).
