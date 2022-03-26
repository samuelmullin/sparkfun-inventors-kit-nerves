defmodule Circuit1a.Morse do
  use GenServer

  require Logger
  alias Circuits.GPIO

  @morse_time_unit 250  #Base time unit for morse blinks in ms
  @morse_map %{
    "a" => ".-",     "b" => "-...",   "c" => "-.-.",   "d" => "-..",
    "e" => ".",      "f" => "..-.",   "g" => "--.",    "h" => "....",
    "i" => "..",     "j" => ".---",   "k" => "-.-",    "l" => ".-..",
    "m" => "--",     "n" => "-.",     "o" => "---",    "p" => ".--.",
    "q" => "--.-",   "r" => ".-.",    "s" => "...",    "t" => "-",
    "u" => "..-",    "v" => "...-",   "w" => ".--",    "x" => "-..-",
    "y" => "-.--",   "z" => "--..",   "1" => ".----",  "2" => "..---",
    "3" => "...--",  "4" => "....-",  "5" => ".....",  "6" => "-....",
    "7" => "--...",  "8" => "---..",  "9" => "----.",  "0" => "-----",
    "." => ".-.-.-", "," => "--..--", "?" => "..--..", " " => ""
  }
  @valid_chars Map.keys(@morse_map)
  @word_ending_chars [" ", ".", ",", "?"]

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # --- Public API ---

  @doc """
    Accepts a string and sends an async message to our Genserver attempting to display
    that string in morse code via a blinking LED.  If the value provided was a string,
    returns {:ok, value}.  If the value was not a valid string it returns
    {:error, :invalid_string}.

    We do not guard against characters not in the @morse_map and will simply skip over
    them during our morse conversion.
  """
  def blink_morse(input_string) when is_binary(input_string) do
    GenServer.cast(__MODULE__, {:blink_morse, input_string})
    {:ok, input_string}
  end

  def blink_morse(value) do
    Logger.error("Expected string, received #{inspect(value)}")
    {:error, :invalid_string}
  end

  # --- Callbacks ---
  @impl true
  def init(_) do
    {:ok, output_gpio} = GPIO.open(morse_output_gpio(), :output)
    {:ok, %{output_gpio: output_gpio}}
  end

  @impl true
  def handle_cast({:blink_morse, input_string}, %{output_gpio: output_gpio} = state) do
    string_to_morse(input_string, output_gpio)
    {:noreply, state}
  end

  # --- Private Implementation ---
  defp string_to_morse(input_string, output_gpio) do
    input_string
    |> String.downcase()
    |> String.codepoints()
    |> Enum.map(fn char -> to_morse(char) end)
    |> List.flatten()
    |> Enum.each(fn item -> morse(item, output_gpio) end)
  end

  defp to_morse(char) when char in @valid_chars do
    morse_chars = Map.get(@morse_map, char)
    |> String.codepoints()

    # We delay 6x if we're ending a word, 3x if we're just ending a letter
    delay_ms = case char in @word_ending_chars do
      true  -> 6 * @morse_time_unit
      false -> 3 * @morse_time_unit
    end

    [morse_chars | [delay_ms] ]
  end
  defp to_morse(_), do: [] # Just skip invalid characters

  defp morse(msec, _) when is_integer(msec), do: Process.sleep(msec)
  defp morse(".", output_gpio), do: blink(1, output_gpio)
  defp morse("-", output_gpio),  do: blink(3, output_gpio)

  defp blink(multiplier, output_gpio) do
    GPIO.write(output_gpio, 1)
    Process.sleep(multiplier * @morse_time_unit)
    GPIO.write(output_gpio, 0)
    Process.sleep(@morse_time_unit)
  end

  defp morse_output_gpio(), do: Application.get_env(:circuit1a, :morse_output_gpio)

end
