defmodule HTTPX.Request do
  @moduledoc ~S"""
  A prepared HTTP request.

  Can be modified by processors and replayed multiple times.
  """

  @default_auth [
    basic: HTTPX.Auth.Basic
  ]
  @auth_methods Application.get_env(:httpx, :auth_extensions, []) ++ @default_auth
  @default_timeouts [
    connect_timeout: 5_000,
    recv_timeout: 15_000
  ]
  @default_ssl_options [ssl_options: [versions: [:"tlsv1.2"]]]

  if p = Application.get_env(:httpx, :default_pool, :default) do
    @default_settings [{:pool, p} | @default_timeouts ++ @default_ssl_options]
  else
    @default_settings @default_timeouts ++ @default_ssl_options
  end

  @ssl_verify Application.get_env(:httpx, :ssl_verify, true)

  @user_agent "HTTPX/#{Mix.Project.config()[:version]}"

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
  @spec prepare(atom, String.t(), Keyword.t()) :: {:ok, t} | {:error, atom}
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
    headers = options[:headers] || []

    if List.keymember?(headers, "user-agent", 0),
      do: headers,
      else: [{"user-agent", @user_agent} | headers]
  end

  @spec settings(Keyword.t()) :: list

  if @ssl_verify do
    defp settings(options) do
      settings = Keyword.merge(@default_settings, options[:settings] || [])

      settings =
        if ssl = settings[:ssl_options] do
          ssl =
            Keyword.merge(
              [
                versions: [:"tlsv1.2"],
                verify: :verify_peer,
                cacertfile: :certifi.cacertfile(),
                depth: 3
              ],
              ssl
            )

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
end
