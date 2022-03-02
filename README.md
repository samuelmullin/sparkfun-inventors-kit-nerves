# Sparkfun Inventors Kit: Nerves

This repo is my attempt to recreate the circuits from the [Sparkfun Inventors Kit](https://www.sparkfun.com/products/15267) using [Nerves](https://www.nerves-project.org/) on a Raspberry Pi Zero.


My instructions work for my case  - that is, I am using elixir and nerves on an M1 Macbook running Monterey.  You might find some of the instructions don't work perfectly for you if this is not your scenario.  In order to use nerves, we have to take a number of steps.  I will presuppose that we have homebrew installed, but if you don’t you can follow the instructions (here)[https://brew.sh/].

We will also use (asdf)[https://asdf-vm.com/] to manage Elixir and Erlang versions.

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

Finally, we will hop into our project directory, install our project dependencies, generate a firmware and burn that firmware to an attached SD card.

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

Welcome to the wonderful world of Nerves!  If you're ready to get building, you can move on to (circuit1a)[./circuit1a]!

