# Circuit 1C - Photoresistor

## Overview

In [Circuit 1C](./base), you'll use a photoresistor to control an LED, which will only turn on when the room is dark enough.  Like [Circuit 1B](../circuit1b) you'll use and ADC to allow for reading the analog input from the photoresistor.

## Challenges

There are no challenge implementations for this circuit as they don't diverge from the base logic enough to warrant including.

## Hardware

In order to complete these circuits, you'll need the following:

- 1 x Breadboard
- 1 x LED - Colour doesn't really matter here, but we don't want RGB
- 1 x 330ohm Resistor
- 1 x 10kohm Resistor
- 5 x M-F Jumper cables
- 3 x M-M Jumper cables
- 1 x Analog Photoresistor
- 1 x ADC1115 Analog-to-Digital Converter

## New Concepts

### Photoresistor

A photoresistor decreases resistance as the amount of light it is exposed to increases.  In line with our photoresistor we include a 10k ohm as including a fixed resistor to act as a [voltage divider](https://learn.sparkfun.com/tutorials/voltage-dividers/all).  

Since this is an analog sensor, and the Raspberry Pi doesn't have any analog pins built in, an analog to digital converter is required.
