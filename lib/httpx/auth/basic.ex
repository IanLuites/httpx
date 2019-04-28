defmodule HTTPX.Auth.Basic do
  @moduledoc false
  use HTTPX.Auth

  @impl HTTPX.Auth
  def auth(req = %{headers: headers}, options) do
    username = options[:username]
    password = options[:password]
    token = Base.encode64("#{username}:#{password}")

    %{req | headers: [{"authorization", "Basic " <> token} | headers]}
  end
end
