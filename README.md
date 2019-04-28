# HTTPX

[![Hex.pm](https://img.shields.io/hexpm/v/httpx.svg "Hex")](https://hex.pm/packages/httpx)
[![Build Status](https://travis-ci.org/IanLuites/httpx.svg?branch=master)](https://travis-ci.org/IanLuites/httpx)
[![Coverage Status](https://coveralls.io/repos/github/IanLuites/httpx/badge.svg?branch=master)](https://coveralls.io/github/IanLuites/httpx?branch=master)
[![Hex.pm](https://img.shields.io/hexpm/l/httpx.svg "License")](LICENSE)


Elixir HTTP client with plug like processors.

## Quick Setup

```elixir
> HTTPX.get("http://ifconfig.co", headers: [{"user-agent", "curl"}])
{:ok,
 %HTTPX.Response{
   body: "91.181.146.99\n",
   headers: [
     {"Date", "Sun, 28 Apr 2019 07:08:25 GMT"},
     {"Content-Type", "text/plain; charset=utf-8"},
     {"Content-Length", "14"},
     {"Connection", "keep-alive"},
     {"Set-Cookie",
      "__cfduid=...; expires=Mon, 27-Apr-20 07:08:25 GMT; path=/; domain=.ifconfig.co; HttpOnly"},
     {"Via", "1.1 vegur"},
     {"Expect-CT",
      "max-age=604800, report-uri=\"https://report-uri.cloudflare.com/cdn-cgi/beacon/expect-ct\""},
     {"Server", "cloudflare"},
     {"CF-RAY", "...-LHR"}
   ],
   status: 200
 }}
```

## Installation

The package can be installed
by adding `httpx` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:httpx, "~> 0.1.0"}]
end
```

The docs can
be found at [https://hexdocs.pm/httpx](https://hexdocs.pm/httpx).

## Settings

### SSL / TLS

SSL options can be passed as `:ssl_options`.

Certificate validation is always performed with the CA bundle adapted from Mozilla by https://certifi.io  in the [certifi](https://hex.pm/packages/certifi) package.

By default certificates are verified to a a depth of level 2, which means the path can be PEER, CA, CA, ROOT-CA, and so on.

To disable verification pass `verify: :verify_none`.

For more options see
[Erlang SSL Options (COMMON)](http://erlang.org/doc/man/ssl.html#TLS/DTLS%20OPTION%20DESCRIPTIONS%20-%20COMMON%20for%20SERVER%20and%20CLIENT)
and
[Erlang SSL Options (CLIENT)](http://erlang.org/doc/man/ssl.html#TLS/DTLS%20OPTION%20DESCRIPTIONS%20-%20CLIENT)
documentation.

## Logging

## Processors

## Streaming

## Changelog

### 0.1.0 (2019-04-x)

New features:

* `HTTPX.Request` module to store request information and allow for request replays.
* `HTTPX.Auth` can now modify more than headers.

Changes:

* `HTTPX.Auth` now applies to a `HTTPX.Request` and not a tuple.
* `HTTPX.Auth` now returns a [modified] `HTTPX.Request` and not a list of headers.
* SSL certificates are now verified by default. Use `config :httpx, ssl_verify: false` to disable verification.

Optimizations:

* ...

Bug fixes:

* ...

## License

_HTTPX_ source code is released under [the MIT License](LICENSE).
Check [LICENSE](LICENSE) file for more information.
