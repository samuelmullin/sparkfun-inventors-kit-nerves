# Building/Uploading Firmware

First, check the target

`echo $MIX_TARGET`

If it's not the expected value, or it's blank, [set the target](https://hexdocs.pm/nerves/targets.html)

`export MIX_TARGET=rpi0`

Then run `mix firmware` from the root directory of the circuit to build the firmware.

Finally, setup the hardware, plug in the device and after it has booted (~30 seconds depending on the model), run `mix upload` to load the firmware onto the device.

The device will reboot and the code from the firmware will be executed.