defmodule HTTPX.Process.Helpers do
  @moduledoc false
  @compile {:inline, do_init: 1, do_pre_request: 2, do_post_request: 2, do_post_parse: 2}

  @doc false
  @spec do_init({module, term}) :: {module, term} | no_return
  def do_init({k, v}) do
    case k.init(v) do
      {:ok, new} -> {k, new}
      {:error, reason} -> raise "Failed to init #{k}: #{reason}"
      opts -> {k, opts}
    end
  end

  @doc false
  @spec do_pre_request([{module, term}], HTTPX.Request.t()) :: HTTPX.Request.t()
  def do_pre_request([], req), do: req

  def do_pre_request([{p, opts} | rest], req) do
    case p.pre_request(req, opts) do
      :ok -> do_pre_request(rest, req)
      {:ok, req} -> do_pre_request(rest, req)
      error = {:error, _} -> error
    end
  end

  @doc false
  @spec do_post_request([{module, term}], tuple) :: tuple
  def do_post_request([], req), do: req

  def do_post_request([{p, opts} | rest], req) do
    case p.post_request(req, opts) do
      :ok -> do_post_request(rest, req)
      {:ok, req} -> do_post_request(rest, req)
      error = {:error, _} -> error
    end
  end

  @doc false
  @spec do_post_parse([{module, term}], tuple) :: tuple
  def do_post_parse([], req), do: {:ok, req}

  def do_post_parse([{p, opts} | rest], req) do
    case p.post_parse(req, opts) do
      :ok -> do_post_parse(rest, req)
      {:ok, req} -> do_post_parse(rest, req)
      error = {:error, _} -> error
    end
  end
end

defmodule HTTPX.Process do
  @moduledoc ~S"""
  HTTPX process module.

  Applies all processors to the HTTPX request.
  """
  import HTTPX.Process.Helpers

  @processors :httpx
              |> Application.compile_env(:processors, [])
              |> Enum.map(&if(is_tuple(&1), do: &1, else: {&1, []}))

  # PRE REQUEST
  @doc ~S"Apply all pre request processors."
  @spec pre_request(HTTPX.Request.t()) :: HTTPX.Request.t() | {:error, term}
  def pre_request(req),
    do:
      @processors
      |> Enum.filter(fn {p, _} -> :pre_request in p.__processor__ end)
      |> Enum.map(&do_init/1)
      |> do_pre_request(req)

  # POST REQUEST
  @doc ~S"Apply all post request processors."
  @spec post_request(tuple) :: tuple
  def post_request(req),
    do:
      @processors
      |> Enum.filter(fn {p, _} -> :post_request in p.__processor__ end)
      |> Enum.map(&do_init/1)
      |> do_post_request(req)

  # POST PARSE

  @doc ~S"Apply all post parse processors."
  @spec post_parse({:ok, HTTPX.Response.t()}) :: {:ok, HTTPX.Response.t()} | {:error, term}
  def post_parse(req),
    do:
      @processors
      |> Enum.filter(fn {p, _} -> :post_parse in p.__processor__ end)
      |> Enum.map(&do_init/1)
      |> do_post_parse(req)

  require Logger

  @doc ~S"""
  Optimizes the `HTTPX.Process` module, unless `config :httpx, dynamic: true`.

  The optimization involves optimizing the calls to all processors.
  """
  @spec optimize :: :ok
  # credo:disable-for-next-line
  def optimize do
    if Application.get_env(:httpx, :dynamic, false) do
      Logger.debug(fn -> "HTTPX: Optimize process (false)" end)
      :ok
    else
      Logger.debug(fn -> "HTTPX: Optimize process (true)" end)

      # Pre load all processors
      :httpx
      |> Application.get_env(:processors, [])
      |> Enum.map(&if(is_tuple(&1), do: &1, else: {&1, []}))
      |> Enum.each(&Code.ensure_loaded(elem(&1, 0)))

      Code.compiler_options(ignore_module_conflict: true)

      Code.compile_quoted(
        quote do
          defmodule HTTPX.Process do
            @moduledoc ~S"""
            HTTPX process module.

            Applies all processors to the HTTPX request.
            """
            import HTTPX.Process.Helpers

            @processors :httpx
                        |> Application.compile_env(:processors, [])
                        |> Enum.map(&if(is_tuple(&1), do: &1, else: {&1, []}))
                        |> Enum.map(&do_init/1)

            # PRE REQUEST
            @pre_request Enum.filter(@processors, fn {p, _} -> :pre_request in p.__processor__ end)
            if Enum.count(@pre_request) > 0 do
              def pre_request(req), do: do_pre_request(@pre_request, req)
            else
              def pre_request(req), do: req
            end

            # POST REQUEST
            @post_request Enum.filter(@processors, fn {p, _} ->
                            :post_request in p.__processor__
                          end)
            if Enum.count(@post_request) > 0 do
              def post_request(req), do: do_post_request(@post_request, req)
            else
              def post_request(req), do: req
            end

            # POST PARSE
            @post_parse Enum.filter(@processors, fn {p, _} -> :post_parse in p.__processor__ end)
            if Enum.count(@post_parse) > 0 do
              def post_parse(req), do: do_post_parse(@post_parse, req)
            else
              def post_parse(req), do: {:ok, req}
            end

            @spec optimize :: :ok
            def optimize, do: :ok
          end
        end
      )

      Code.compiler_options(ignore_module_conflict: false)

      :ok
    end
  end
end
