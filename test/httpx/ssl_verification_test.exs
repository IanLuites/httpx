defmodule HTTPX.SSLVerificationTest do
  use ExUnit.Case

  test "by default uses SSL verification" do
    assert HTTPX.get("https://self-signed.badssl.com/") ==
             {:error,
              {:tls_alert, {:bad_certificate, 'received CLIENT ALERT: Fatal - Bad Certificate'}}}

    assert {:ok, _} = HTTPX.get("https://ifconfig.co/")
  end

  test "with custom :ssl_options, makes sure it uses SSL verification" do
    settings = [ssl_options: [versions: [:"tlsv1.2"]]]

    assert HTTPX.get("https://self-signed.badssl.com/", settings: settings) ==
             {:error,
              {:tls_alert, {:bad_certificate, 'received CLIENT ALERT: Fatal - Bad Certificate'}}}

    assert {:ok, _} = HTTPX.get("https://ifconfig.co/", settings: settings)
  end

  test "allows overwriting of verification" do
    settings = [ssl_options: [verify: :verify_none]]

    assert {:ok, _} = HTTPX.get("https://self-signed.badssl.com/", settings: settings)
  end
end