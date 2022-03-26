# Troubleshooting

## Hardware
When troubleshooting, the first thing to do is always to check the wiring of your circuit.

- Are the connections correct?  Check that the correct GPIOs have been connected to the breadboard.  Remember that the breadboard has connections across horizontal rows on each side of the board and that could be shorting components that have multiple leads in the same row
- Is the polarity of the devices correct?  Check that devices that are sensitive to polarity (such as LEDs) are installed in the correct orientation.
- If there is a resistor in the circuit, is it the correct resistance?  You can verify using the [coloured rings on the side](https://www.calculator.net/resistor-calculator.html)
  

## Logs

Once hardware is ruled out, the first thing to do to verify software is to check the logs.  Logs are obtained by SSHing into the device and using the [Ringlogger library](https://github.com/nerves-project/ring_logger) which is included in the nerves boilerplate.

```bash
ssh nerves.local
RingLogger.attach
RingLogger.next
```

The logs should give a hint as to why the circuit is not working.  If there is no obvious error, like the GenServer crashing, try replacing the components in the circuit (jumper cables, led, resistor) one at a time.
