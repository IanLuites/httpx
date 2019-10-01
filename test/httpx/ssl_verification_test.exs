defmodule HTTPX.SSLVerificationTest do
  use ExUnit.Case, async: true

  # Thanks: https://badssl.com/

  test "by default uses SSL verification" do
    assert HTTPX.get("https://self-signed.badssl.com/", settings: [pool: :fail_tls_self]) ==
             {:error,
              {:tls_alert,
               {:bad_certificate,
                'TLS client: In state certify at ssl_handshake.erl:1664 generated CLIENT ALERT: Fatal - Bad Certificate\n'}}}

    assert {:ok, _} = HTTPX.get("https://ifconfig.co/")
  end

  test "with custom :ssl_options, makes sure it uses SSL verification" do
    settings = [ssl_options: [versions: [:"tlsv1.2"]], pool: :fail_tls_self_merged]

    assert HTTPX.get("https://self-signed.badssl.com/", settings: settings) ==
             {:error,
              {:tls_alert,
               {:bad_certificate,
                'TLS client: In state certify at ssl_handshake.erl:1664 generated CLIENT ALERT: Fatal - Bad Certificate\n'}}}

    assert {:ok, _} = HTTPX.get("https://ifconfig.co/", settings: settings)
  end

  test "allows overwriting of verification" do
    settings = [ssl_options: [verify: :verify_none]]

    assert {:ok, _} = HTTPX.get("https://self-signed.badssl.com/", settings: settings)
  end
end
