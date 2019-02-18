defmodule HTTPX.Log do
  defmacro __using__(_opts \\ []) do
    quote do
      alias HTTPX.Log
      require HTTPX.Log
      require Logger
    end
  end

  @default_opts [type: :none, pre: false, post: true, prefix: <<>>, status_type: false]

  defp settings do
    opts =
      case Application.get_env(:httpx, :log) do
        nil -> @default_opts
        type when is_atom(type) -> Keyword.put(@default_opts, :type, type)
        opts -> Keyword.merge(@default_opts, opts)
      end

    Keyword.pop(opts, :type)
  end

  defmacro log(info) do
    {type, _opts} = settings()

    case type do
      :none ->
        nil

      level when level in ~w(debug info error warn)a ->
        {{:., [], [{:__aliases__, [alias: false], [:Logger]}, level]}, [],
         [
           quote do
             fn -> unquote(info) end
           end
         ]}
    end
  end

  defmacro log(method, url, _headers, _body) do
    {type, opts} = settings()

    if opts[:pre] do
      case type do
        :none ->
          nil

        level when level in ~w(debug info error warn)a ->
          {{:., [], [{:__aliases__, [alias: false], [:Logger]}, level]}, [],
           [
             quote do
               fn ->
                 unquote(opts[:prefix]) <>
                   "#{unquote(method) |> to_string |> String.upcase()} #{unquote(url)}"
               end
             end
           ]}
      end
    end
  end

  defmacro log(method, url, _headers, _body, response) do
    {type, opts} = settings()

    if opts[:post] do
      case type do
        :none ->
          nil

        level when level in ~w(debug info error warn)a ->
          {{:., [], [{:__aliases__, [alias: false], [:Logger]}, level]}, [],
           [
             quote do
               fn ->
                 r =
                   case unquote(response) do
                     {:ok, status, _} -> "(#{status})"
                     {:ok, status, _, _} -> "(#{status})"
                     {:error, reason} -> "(failed: #{reason})"
                   end

                 unquote(opts[:prefix]) <>
                   "#{unquote(method) |> to_string |> String.upcase()} #{unquote(url)} #{r}"
               end
             end
           ]}
      end
    end
  end
end
