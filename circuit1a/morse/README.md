# Circuit 1A

## Overview

For this challenge, the blinking LED circuit we created is used to convey messages via morse code.

## Usage

After [creating and uploading the firmware](../../FIRMWARE.md), ssh into the device and use the public API to send messages.

```bash
ssh nerves.local
iex(1)> Circuit1a.Morse.blink_morse("hello world")
```

The LED should blink the message back to you in morse code, and you should see a return in your console of `{:ok, "hello world"}`.  

If the LED does not blink as expected, refer to the [Troubleshooting Guide](../../TROUBLESHOOTING.md)


## Hardware

There are no changes to the hardware from the [base circuit](../base/README.md#hardware)

## Wiring

There are no changes to the wiring from the [base circuit](../base/README.md#wiring)

## Application Definition & Dependencies

There are no changs to the Application Definiton & Dependencies from the [base circuit](../base/README.md#application-definition--dependencies)

## Config

The [config](./config/config.exs) for this version of the circuit was updated to include a `blink_default_ms` with a value of 500.

```Elixir
config :circuit1a,
  morse_output_gpio: 26
```


## Supervision

There are no changes to the Supervision from the [base circuit](../base/README.md#supervision)


## Application Logic

The application logic for this circuit is contained in the [Circuit1a.Blink module](./lib/morse.ex).

A few morse code basics:
  - Morse can use any base time unit as long as it's consistent.
  - A dot is 1 time unit, a dash is 3.
  - There is a gap of 3 time units between letters and a gap of 6 time units between words

```elixir
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
  ```

  A number of module attributes are defined, including the base time unit in miliseconds, a map of characters to morse codes, a list of valid characters and a list of characters that denote the end of words.

  One important note here:  because `@valid_chars` is a module attribute, the Map.keys function is invoked only once on compile.

```elixir
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
```  

The public api consists of one function, which accept a [valid string](https://hexdocs.pm/elixir/1.12/String.html) as input and returns `{:error, :invalid string}` if it does not receive one.

Upon receiving a valid string, the function uses [GenServer.cast/2](https://hexdocs.pm/elixir/1.13/GenServer.html#cast/2) to send a message to the Circuit1a.Morse genserver with the content {:blink_morse, input_string}.

```elixir
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
```

The callback that receives the `{:blink_morse, input_string}` message uses the string along with the output_gpio to call a private function, `string_to_morse/2`.

```elixir
 # --- Private Implementation ---
  defp string_to_morse(input_string, output_gpio) do
    input_string
    |> String.downcase()
    |> String.codepoints()
    |> Enum.map(fn char -> to_morse(char) end)
    |> List.flatten()
    |> Enum.each(fn item -> morse(item, output_gpio) end)
  end
```

This is a great example of an Elixir pipeline.  The pipeline operator (`|>`) takes the output of the previous function and passes it to the next function as the first parameter. 

The pipeline above works like this:

- The input string is passed to String.downcase/1, which returns a string with all lower case letters
- The lowercase string is passed to String.codepoints/1, which returns a list of codepoints (single characters)
- The list of characters is passed to Enum.map/2, which converts each character to a list of morse code symbols.
- The list of lists is passed to List.flatten, which collapses all the lists into a single list and returns it
- The flattened list of morse characters is passed into Enum.each/2, which handles blinking the led for that character

```elixir
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
```

This function handles the conversion from string characters to morse characters. It fetches the morse symbols (dots/dashes) from the `@morse_map`, converts them to a list of codepoints and then adds the correct delay.

```elixir
  defp morse(msec, _) when is_integer(msec), do: Process.sleep(msec)
  defp morse(".", output_gpio), do: blink(1, output_gpio)
  defp morse("-", output_gpio),  do: blink(3, output_gpio)

  defp blink(multiplier, output_gpio) do
    GPIO.write(output_gpio, 1)
    Process.sleep(multiplier * @morse_time_unit)
    GPIO.write(output_gpio, 0)
    Process.sleep(@morse_time_unit)
  end
```

`morse/2` and `blink/2` handle actually blinking the led or pausing, depending on whether a dot, dash or integer are received.
