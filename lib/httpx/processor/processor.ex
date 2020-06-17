defmodule HTTPX.Processor do
  @moduledoc ~S"""
  HTTPX processor module.

  Processors allow users to change or update requests,
  during a request lifetime.

  Processors are applied to all requests by `HTTPX` and
  are an ideal way to insert tracking or metrics.

  ## Configure

  The processors can be given as a list, which will be applied in order.

  ```
  config :httpx, processors: [Example.Processor]
  ```

  Processors will be optimized on startup and can't be dynamically added or removed.

  If such functionality is required, then the following flag needs to be set:

  ```
  config :httpx, dynamic: true
  ```

  ## Processor Lifetime

  The lifetime of a processor is:
  `init/1` => `pre_request/2` => `post_request/2` => `post_parse/2`.

  The `init/1`, might be called multiple times,
  but no more than once per request.

  ## Hooks

  Each processor can use the following hooks:

  ### init/1

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

  ### pre_request/2

  The `pre_request/2` hook is called before the request is performed.
  It can be used to change
  or add to the details of a request, before it is
  performed.

  For example this adds a custom tracking header to all requests:
  ```
  @impl HTTPX.Processor
  def pre_request(req = %{headers: req_headers}, %{header: header}) do
    {:ok, %{req | headers: [{header, "..."} | req_headers]}}
  end
  ```
  (Note the `header` comes from the `init/1` above.)

  ### post_request/2

  The `post_request/2` hook is called after the request is performed,
  but before the response is parsed.

  ### post_parse/2

  The `post_parse/2` hook is called after the response is parsed.

  ## Example

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
  """
  @doc ~S"Initialize processor."
  @callback init(opts :: term) :: {:ok, opts :: term}

  @doc ~S"Pre request processor."
  @callback pre_request(HTTPX.Request.t(), opts :: term) :: :ok | {:ok, HTTPX.Request.t()}

  @doc ~S"Post request processor."
  @callback post_request(any, opts :: term) :: :ok

  @doc ~S"Post parse processor."
  @callback post_parse(any, opts :: term) :: :ok

  @doc false
  @callback __processor__ :: [atom]

  @overridable [init: 1, pre_request: 2, post_request: 2, post_parse: 2]

  @doc @moduledoc
  defmacro __using__(_ \\ []) do
    quote location: :keep do
      Module.register_attribute(__MODULE__, :processor_impl, accumulate: true)
      @before_compile unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      @doc ~S"Initialize processor."
      @impl unquote(__MODULE__)
      def init(opts), do: {:ok, opts}

      @doc ~S"Pre request processor."
      @impl unquote(__MODULE__)
      def pre_request(_req, _opts), do: :ok

      @doc ~S"Post request processor."
      @impl unquote(__MODULE__)
      def post_request(_result, _opts), do: :ok

      @doc ~S"Post parse processor."
      @impl unquote(__MODULE__)
      def post_parse(_req, _opts), do: :ok

      defoverridable unquote(@overridable)
      @on_definition {unquote(__MODULE__), :track_impl}

      # Reset specs, because something weird happens
      # with defoverridable
      @spec __processor__ :: [atom]
      @spec init(opts :: term) :: {:ok, opts :: term}
      @spec pre_request(HTTPX.Request.t(), opts :: term) :: :ok | {:ok, HTTPX.Request.t()}
      @spec post_request(any, opts :: term) :: :ok
      @spec post_parse(any, opts :: term) :: :ok
    end
  end

  @doc false
  @spec track_impl(any, :def | :defp, atom, [atom], any, any) :: any
  def track_impl(env, :def, name, args, _guards, _body) do
    if {name, Enum.count(args)} in @overridable do
      Module.put_attribute(env.module, :processor_impl, name)
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    implemented = Module.get_attribute(env.module, :processor_impl) || []

    quote do
      @doc false
      @impl unquote(__MODULE__)
      def __processor__, do: unquote(implemented)
    end
  end
end
