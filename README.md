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

Processors allow users to change or update requests,
during a request lifetime.

Processors are applied to all requests by `HTTPX` and
are an ideal way to insert tracking or metrics.

### Configure

The processors can be given as a list, which will be applied in order.

```
config :httpx, processors: [Example.Processor]
```

Processors will be optimized on startup and can't be dynamically added or removed.

If such functionality is required, then the following flag needs to be set:

```
config :httpx, dynamic: true
```

### Processor Lifetime

The lifetime of a processor is:
`init/1` => `pre_request/2` => `post_request/2` => `post_parse/2`.

The `init/1`, might be called multiple times,
but no more than once per request.

### Hooks

Each processor can use the following hooks:

#### init/1

The `init/1` hook is called to let the processor configure itself.

In the optimized version the `init/1` hook is only called once.
The `init/1` can be called once per request,
when `:httpx` is running in dynamic mode.

For example configuring a tracking header:
```
@impl HTTPX.Processor
def init(opts) do
  header = Keyword.get(opts, :tracking_header, "example")

  {:ok, %{header: header}}
end
```

#### pre_request/2

The `pre_request/2` hook is called before the request is performed.
It can be used to change
or add to the details of a request, before it is
performed.

For example this adds a custom tracking header to all requests:
```
@impl HTTPX.Processor
def pre_request(req = %{headers: headers}, %{header: header}) do
  {:ok, %{req | headers: [{header, "..."} | headers]}}
end
```
(Note the `header` comes from the `init/1` above.)

#### post_request/2

The `post_request/2` hook is called after the request is performed,
but before the request is parsed.

#### post_parse/2

The `post_parse/2` hook is called after the request is parsed.

### Example

This module will redirect all requests to
`https://ifconfig.co` and parse only the IP
in the result.

This module has no real life use and is just
an example.
```
defmodule MyProcessor do
  use HTTPX.Processor

  @impl HTTPX.Processor
  def pre_request(req, opts) do
    {:ok, %{req | url: "https://ifconfig.co"}}
  end

  @match ~r/<code class=\"ip\">(.*)<\/code>/

  @impl HTTPX.Processor
  def post_parse(%{body: body}, _opts) do
    case Regex.run(@match, body) do
      [_, m] -> {:ok, m}
      _ -> :ok
    end
  end

  def post_parse(_, _), do: :ok
end
```

## Streaming

## Changelog

### 0.1.0 (2019-04-x)

New features:

* `HTTPX.Request` module to store request information and allow for request replays.
* `HTTPX.Auth` can now modify more than headers.
* Processors that allow for modifications to requests on a project/application level.

Changes:

* `HTTPX.Auth` now applies to a `HTTPX.Request` and not a tuple.
* `HTTPX.Auth` now returns a [modified] `HTTPX.Request` and not a list of headers.
* SSL certificates are now verified by default. Use `config :httpx, ssl_verify: false` to disable verification.

Optimizations:

* On load HTTPX optimizes the configured processors.

Bug fixes:

* ...

## License

_HTTPX_ source code is released under [the MIT License](LICENSE).
Check [LICENSE](LICENSE) file for more information.
