defmodule HTTPX.Auth.Basic do
  @moduledoc false
  use HTTPX.Auth

  @impl HTTPX.Auth
  def auth(req = %{headers: headers}, options) do
    token = Base.encode64("#{options[:username]}:#{options[:password]}")
    %{req | headers: [{"authorization", "Basic " <> token} | headers]}
  end
end
