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

## Logging

## Processors

## Streaming

## License

_HTTPX_ source code is released under [the MIT License](LICENSE).
Check [LICENSE](LICENSE) file for more information.
