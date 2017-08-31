defmodule HTTPX.RequestError do
  @predefined_messages [

  ]

  defexception [
    :message,
    :code,
    :url,
    :headers,
    :body,
    :options,
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
      options: clean_options,
    }
  end
end
