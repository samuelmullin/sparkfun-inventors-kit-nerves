# This file is responsible for configuring your application and its
# dependencies.
#
# This configuration file is loaded before any dependency and is restricted to
# this project.
import Config

# Enable the Nerves integration with Mix
Application.start(:nerves_bootstrap)

config :circuit1b, target: Mix.target()

# Customize non-Elixir parts of the firmware. See
# https://hexdocs.pm/nerves/advanced-configuration.html for details.

config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

# Set the SOURCE_DATE_EPOCH date for reproducible builds.
# See https://reproducible-builds.org/docs/source-date-epoch/ for more information

config :nerves, source_date_epoch: "1646185297"

# Use Ringlogger as the logger backend and remove :console.
# See https://hexdocs.pm/ring_logger/readme.html for more information on
# configuring ring_logger.

config :logger, backends: [RingLogger]

config :circuit1b,
  led_gpio: 26,
  max_reading: 27235,
  adc1115_address: 72

if Mix.target() == :host or Mix.target() == :"" do
  import_config "host.exs"
else
  import_config "target.exs"
end
