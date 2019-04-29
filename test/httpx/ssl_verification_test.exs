defmodule HTTPX.SSLVerificationTest do
  use ExUnit.Case, async: true

  test "by default uses SSL verification" do
    assert HTTPX.get("https://self-signed.badssl.com/", settings: [pool: :fail_tls_self]) ==
             {:error,
              {:tls_alert, {:bad_certificate, 'received CLIENT ALERT: Fatal - Bad Certificate'}}}

    assert {:ok, _} = HTTPX.get("https://ifconfig.co/")
  end

  test "with custom :ssl_options, makes sure it uses SSL verification" do
    settings = [ssl_options: [versions: [:"tlsv1.2"]], pool: :fail_tls_self_merged]

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
