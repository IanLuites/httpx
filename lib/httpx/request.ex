defmodule HTTPX.Request do
  require Logger

  @moduledoc ~S"""
  A prepared HTTP request.

  Can be modified by processors and replayed multiple times.
  """

  @default_auth [
    basic: HTTPX.Auth.Basic
  ]
  @auth_methods Application.compile_env(:httpx, :auth_extensions, []) ++ @default_auth
  @default_timeouts [
    connect_timeout: 5_000,
    recv_timeout: 15_000
  ]
  @default_ssl_options [ssl_options: [versions: [:"tlsv1.2"]]]

  if p = Application.compile_env(:httpx, :default_pool, :default) do
    @default_settings [{:pool, p} | @default_timeouts ++ @default_ssl_options]
  else
    @default_settings @default_timeouts ++ @default_ssl_options
  end

  @ssl_verify Application.compile_env(:httpx, :ssl_verify, true)
  @user_agent "HTTPX/#{Mix.Project.config()[:version]}"

  @trace_config Application.compile_env(:httpx, :trace_settings, %{})
  @trace_settings is_map(@trace_config) &&
                    Map.merge(@trace_config, %{header: "x-request-id", key: :request_id})
  @trace_header @trace_settings && Map.fetch!(@trace_settings, :header)
  @trace_key @trace_settings && Map.fetch!(@trace_settings, :key)

  @doc false
  @spec __default_settings__ :: Keyword.t()
  def __default_settings__, do: @default_settings

  @typedoc @moduledoc
  @type t :: %__MODULE__{
          method: atom,
          url: String.t(),
          headers: [{String.t(), String.t()}],
          body: binary,
          format: atom,
          fail: boolean,
          settings: list,
          meta: map
        }

  defstruct [
    :method,
    :url,
    :headers,
    :body,
    :format,
    :fail,
    :settings,
    meta: %{}
  ]

  @doc ~S"""
  Prepare a request.
  """
  @spec prepare(atom, String.t(), Keyword.t()) :: t
  def prepare(method, url, options \\ []) do
    request = %__MODULE__{
      method: method,
      url: generate_url(url, options),
      headers: headers(options),
      body: options[:body] || "",
      settings: settings(options),
      format: options[:format] || :text,
      fail: options[:fail] || false
    }

    auth = options[:auth]

    if auth_method = @auth_methods[auth] || auth do
      auth_method.auth(request, options)
    else
      request
    end
  end

  ### Helpers ###

  @spec headers(Keyword.t()) :: [{String.t(), String.t()}]
  defp headers(options) do
    options
    |> Keyword.get(:headers, [])
    |> validate_headers()
    |> header_user_agent()
    |> trace_headers()
  end

  defp validate_headers(headers)
  defp validate_headers(headers) when is_list(headers), do: headers

  defp validate_headers(_headers) do
    Logger.warning(
      ~S|Invalid headers passed. Headers should be in the format: [{"header", "value"}]|
    )

    []
  end

  defp header_user_agent(headers) do
    if List.keymember?(headers, "user-agent", 0),
      do: headers,
      else: [{"user-agent", @user_agent} | headers]
  end

  defp trace_headers(headers)

  if @trace_settings do
    defp trace_headers(headers) do
      id = Keyword.get(Logger.metadata(), @trace_key, false)

      if is_binary(id) and not List.keymember?(headers, @trace_header, 0) do
        [{@trace_header, id} | headers]
      else
        headers
      end
    end
  else
    defp trace_headers(headers), do: headers
  end

  @spec settings(Keyword.t()) :: list

  if @ssl_verify do
    defp settings(options) do
      settings = Keyword.merge(@default_settings, options[:settings] || [])

      settings =
        if ssl = settings[:ssl_options] do
          ssl = Keyword.merge(base_ssl(), ssl)
          Keyword.put(settings, :ssl_options, ssl)
        else
          settings
        end

      if options[:format] == :stream, do: settings, else: [:with_body | settings]
    end
  else
    defp settings(options) do
      settings = Keyword.merge(@default_settings, options[:settings] || [])
      if options[:format] == :stream, do: settings, else: [:with_body | settings]
    end
  end

  @spec generate_url(String.t(), Keyword.t()) :: String.t()
  defp generate_url(url, options) do
    uri = URI.parse(url)

    full_url =
      cond do
        not Keyword.has_key?(options, :params) ->
          url

        uri.query ->
          url <> "&" <> HTTPX.query_encode(options[:params] || %{})

        uri.path ->
          url <> "?" <> HTTPX.query_encode(options[:params] || %{})

        true ->
          url <> "/?" <> HTTPX.query_encode(options[:params] || %{})
      end

    full_url
    |> to_string
    |> default_process_url
  end

  @spec default_process_url(String.t()) :: String.t()
  defp default_process_url(url) do
    case url |> String.slice(0, 12) |> String.downcase() do
      "http://" <> _ -> url
      "https://" <> _ -> url
      "http+unix://" <> _ -> url
      _ -> "http://" <> url
    end
  end

  @compile {:inline, base_ssl: 0}
  @spec base_ssl :: Keyword.t()
  if :erlang.system_info(:otp_release)
     |> to_string
     |> String.split(".")
     |> List.first()
     |> String.to_integer()
     |> Kernel.>=(21) do
    defp base_ssl,
      do: [
        versions: [:"tlsv1.2"],
        verify: :verify_peer,
        cacertfile: :certifi.cacertfile(),
        depth: 99,
        # crl_check: :peer,
        crl_check: :best_effort,
        crl_cache: {:ssl_crl_cache, {:internal, [{:http, 5_000}]}},
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
  else
    defp base_ssl,
      do: [
        versions: [:"tlsv1.2"],
        verify: :verify_peer,
        cacertfile: :certifi.cacertfile(),
        depth: 99
      ]
  end
end
