defmodule HTTPX.RequestError do
  alias HTTPX.Request
  @predefined_messages []

  defexception [
    :message,
    :code,
    :url,
    :headers,
    :body,
    :options
  ]

  def exception(reason, message \\ nil, context \\ []) do
    options = context[:options] || []

    clean_options =
      options
      |> Keyword.delete(:body)
      |> Keyword.delete(:headers)

    %__MODULE__{
      code: reason,
      message: message || @predefined_messages[reason] || to_string(reason),
      url: context[:url],
      headers: context[:headers] || options[:headers] || [],
      body: context[:body] || options[:body],
      options: clean_options
    }
  end

  def message(exception) do
    [
      to_string(exception.code),
      "\r\n  url: ",
      exception.url,
      if exception.options[:params] do
        "\r\n  params:\r\n    " <> print_data(exception.options[:params])
      else
        nil
      end,
      if exception.body do
        case exception.body do
          {type, body} -> "\r\n  body: (#{type}) \r\n    " <> print_data(body)
          body -> "\r\n  body:\r\n\"\"\"\r\n" <> body <> "\r\n\"\"\""
        end
      else
        nil
      end,
      if exception.headers != [] do
        "\r\n  headers:\r\n    " <> print_data(exception.headers)
      else
        nil
      end,
      if exception.options[:settings] do
        hackney_settings =
          Request.__default_settings__()
          |> Keyword.merge(exception.options[:settings])

        "\r\n  hackney:\r\n    " <> print_data(hackney_settings)
      else
        nil
      end,
      "\r\n  Trace:"
    ]
    |> Enum.reject(&is_nil/1)
    |> IO.iodata_to_binary()
  end

  defp print_data(data, key_converter \\ &to_string/1) do
    data
    |> Enum.map(fn
      {k, v} -> key_converter.(k) <> ": " <> inspect(v)
      value -> inspect(value)
    end)
    |> Enum.join("\r\n    ")
  end
end
