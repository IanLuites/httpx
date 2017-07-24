defmodule HTTPX.Auth.Basic do
  @moduledoc false

  @doc false
  @spec auth(atom, String.t, [{String.t, String.t}], String.t, keyword)
   :: [{String.t, String.t}]
  def auth(_method, _url, _headers, _body, options) do
    username = options[:username]
    password = options[:password]

    token =
      "#{username}:#{password}"
      |> Base.encode64

    [{"authorization", "Basic " <> token}]
  end
end
