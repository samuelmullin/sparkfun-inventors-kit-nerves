defmodule Circuit4a.Screen do
  use GenServer

  require Logger

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # --- Callbacks ---
  @impl true
  def init(_) do
    # Get our LCD config and start the LCD GenServer
    lcd_config = Application.fetch_env!(:circuit4a, :lcd_config)
    {:ok, lcd_ref} = LcdDisplay.HD44780.GPIO.start(lcd_config)

    # Clear the screen
    LcdDisplay.HD44780.GPIO.execute(lcd_ref, :clear)

    # Print the first line
    LcdDisplay.HD44780.GPIO.execute(lcd_ref, {:print, "Hello, Nerves!"})

    # Move cursor to start of second line
    LcdDisplay.HD44780.GPIO.execute(lcd_ref, {:set_cursor, 1, 0})

    # Print second line
    LcdDisplay.HD44780.GPIO.execute(lcd_ref, {:print, "42"})

    # Store our references in state so they don't get garbage collected
    {:ok, %{lcd_ref: lcd_ref}}
  end

end
