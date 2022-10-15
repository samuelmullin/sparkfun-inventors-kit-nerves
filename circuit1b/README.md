# Circuit 1B - Potentiometer

## Overview

In [Circuit 1B](./base), you'll use a potentiometer to control the cadence of a blinking LED.  Since a potentiometer is an analog sensor, which the Raspberry Pi can't natively read, you'll also get to use an I2C based analog to digital converter.

## Challenges

If you're interested in seeing example solutions to the challenges for this circuit, you can find them here:

[Multiple LEDs](./multiple_led) extends our base circuit by adding the ability to add additional LEDs by simply adding to the project config.  Also exposes a config option to change the max cadence (which will make the available range larger or smaller)

## Hardware

In order to complete these circuits, you'll need the following:

- 1 x Breadboard
- 3 x LED - Colour doesn't really matter here, but we don't want RGB
- 3 x 330ohm Resistor
- 7 x M-F Jumper cables
- 5 x M-M Jumper cables
- 1 x Analog Potentiometer
- 1 x ADC1115 Analog-to-Digital Converter

## New Concepts

### Potentiometer

A potentiometer is a three terminal resistor.  It uses a control rod (knob) that moves a wiper across a resistive strip.  The further current travels across the strip, the more resistance it encounters. By passing in a known voltage and then reading the voltage that comes out after travelling through the resistance strip, we can determine how far the knob has been turned.

Since this is an analog sensor, and the Raspberry Pi doesn't have any analog pins built in, an analog to digital converter is required.

### Analog Digital Converter

An analog to digital converter works by accepting an analog input and encoding it as a digital input.  There are many different types, but for this tutorial I am using an [ADC1115](https://www.adafruit.com/product/1085).  It has a 16-bit resolution (the value we receive has a max range of 0-65656) and it can do up to 860 samples per second.   

### I2C

[I2C is a communication protocol](https://learn.sparkfun.com/tutorials/i2c/all) that allows us to use two wires to connect multiple devices in a serial fashion via daisy chaining (connecting them to one another).  The downside of I2C is that it only allows for half duplex communication - it can only talk in one direction at a time.  Devices communicating via I2C need to have unique addresses, and most I2C modules allow the user to change the address of the device for this reason.


