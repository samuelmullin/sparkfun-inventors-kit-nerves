# Sparkfun Inventors Kit: Nerves

This repo is my attempt to recreate the circuits from the [Sparkfun Inventors Kit](https://www.sparkfun.com/products/15267) using [Nerves](https://www.nerves-project.org/) on a Raspberry Pi Zero.

## How to use this Repo

The [Sparkfun Inventors Kit](https://www.sparkfun.com/products/15267) has 12 circuits defined.  Each circuit is contained in it's own folder and has:

- A wiring diagram for the Pi Zero including any extra hardware or modifications that were required to run the project using Nerves
- A complete application that can be used to build and burn firmware onto your device
- A high level explanation of the application logic including any new concepts that are being introduced and where this circuit deviates from the Sparkfun circuit.

## Pi Hardware limitations

While they have a similar form factor, there are some key differences between the Arduio and the Raspberry Pi platform.  One of the key differences for the purposes of the Inventors Kit is the lack of analog inputs on the Pi. In some cases, we will use an Analog-Digital Converter (ADC) to interface with an analog sensor, in others we will use a replacement sensor that interfaces via SPI or I2c, and in others we will completely remove or replace the functionality.  A complete hardware list is included below along with links to recommended replacement parts.

## Getting Started

My instructions work for my case  - that is, I am using elixir and nerves on an M1 Macbook running Monterey.  You might find some of the instructions don't work perfectly for you if this is not your scenario.  In order to use nerves, we have to take a number of steps.  I will presuppose that we have homebrew installed, but if you don’t you can follow the instructions [here](https://brew.sh/).

We will also use [asdf](https://asdf-vm.com/) to manage Elixir and Erlang versions.

First thing we are going to install a few packages we will depend on for nerves:

```bash
brew update
brew install fwup squashfs coreutils xz pkg-config
```

Next up we will install our versions of Elixir and Erlang and set them as the default globally:

```bash
asdf install erlang 24.2.1
asdf install elixir 1.13.2-otp-24
asdf global elixir 1.13.2-otp-24
asdf global erlang 24.2.1  
```

Then we will install hex and rebar:

```bash
mix local.hex
mix local.rebar
```
And finally we will install nerves_bootstrap which will allow us to create nerves projects with our global mix command:

```bash
mix archive.install hex nerves_bootstrap
```

Now we can create a new nerves project using mix.  When we run this command, it’s going to create all the nerves boilerplate for us so we can get up and going.   Let’s create the hello world version of a nerves project ala the nerves docs and export a variable to let nerves know that we’re going to be targeting a Raspberry Pi Zero W.

```bash
mix nerves.new hello_nerves
export MIX_TARGET=rpi0
```

The first time around we will need to burn the firmware directly to an attached SD card.  After this initial burn, we can burn the SD card while it's inserted into the running nerves device.

```bash
mix firmware
mix firmware.burn
```

Nerves at this point will attempt to autodetect your SD card - if it doesn’t work, you can specify a target using the -d flag:

```bash
mix firmware.burn -d /dev/yourdiskhere
``` 

Now you can pop the SD in your device and connect it via the data/power port and it should boot into Nerves.  We can test it by pinging it once it completes loading:

```bash
ping nerves.local

PING nerves.local (172.31.245.197): 56 data bytes
64 bytes from 172.31.245.197: icmp_seq=0 ttl=64 time=0.972 ms
```

Welcome to the wonderful world of Nerves!  If you're ready to get building, you can move on to [circuit1a](./circuit1a)!

