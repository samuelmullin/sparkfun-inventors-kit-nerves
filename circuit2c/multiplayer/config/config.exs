# This file is responsible for configuring your application and its
# dependencies.
#
# This configuration file is loaded before any dependency and is restricted to
# this project.
import Config

# Enable the Nerves integration with Mix
Application.start(:nerves_bootstrap)

config :circuit2c, target: Mix.target()

# Customize non-Elixir parts of the firmware. See
# https://hexdocs.pm/nerves/advanced-configuration.html for details.

config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

# Set the SOURCE_DATE_EPOCH date for reproducible builds.
# See https://reproducible-builds.org/docs/source-date-epoch/ for more information

config :nerves, source_date_epoch: "1646483815"

# Use Ringlogger as the logger backend and remove :console.
# See https://hexdocs.pm/ring_logger/readme.html for more information on
# configuring ring_logger.

config :logger, backends: [RingLogger]

config :circuit2c,
  # Tones
  red_tone: 262,
  blue_tone: 294,
  yellow_tone: 330,
  green_tone: 349,

  # LED GPIO Pins
  red_led_pin: 4,
  blue_led_pin: 22,
  yellow_led_pin: 17,
  green_led_pin: 27,

  # Input GPIO Pins
  red_input_pin: 19,
  blue_input_pin: 20,
  yellow_input_pin: 6,
  green_input_pin: 26,
  mode_input_pin: 24,

  # Other
  buzzer_pin: 13


if Mix.target() == :host or Mix.target() == :"" do
  import_config "host.exs"
else
  import_config "target.exs"
end
