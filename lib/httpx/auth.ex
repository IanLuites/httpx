defmodule HTTPX.Auth do
  @moduledoc ~S"""
  Authorization support for HTTP request.

  Can be used for basic auth, HMAC auth, etc.
  """

  @doc ~S"""
  Authorizes a HTTP request using the given method, headers, body, and options.
  """
  @callback auth(atom, String.t, [{String.t, String.t}], String.t, keyword)
             :: [{String.t, String.t}]

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour HTTPX.Auth
    end
  end
end
