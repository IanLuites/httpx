defmodule HTTPX.Auth.Basic do
  @moduledoc false

  use HTTPX.Auth

  @impl true
  def auth(_method, _url, _headers, _body, options) do
    username = options[:username]
    password = options[:password]

    token =
      "#{username}:#{password}"
      |> Base.encode64

    [{"authorization", "Basic " <> token}]
  end
end
