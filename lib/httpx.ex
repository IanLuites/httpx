defmodule HTTPX do
  @moduledoc ~S"""
  Simple HTTP(s) client with integrated auth methods.
  """

  alias HTTPX.RequestError
  alias HTTPX.Response

  @type post_body :: String.t | {:urlencoded, map | keyword} | {:json, map | keyword | String.t}

  @default_auth [
    basic: HTTPX.Auth.Basic
  ]
  @auth_methods Application.get_env(:httpx, :auth_extensions, @default_auth)

  @default_settings [
    ssl_options: [versions: [:'tlsv1.2']],
    pool: :default,
    connect_timeout: 5_000,
    recv_timeout: 15_000,
  ]

  @post_header_urlencoded {"Content-Type", "application/x-www-form-urlencoded"}
  @post_header_json {"Content-Type", "application/json"}

  @dialyzer {
    [:no_return, :no_match, :nowarn_function],
    get: 1,
    get: 2,
    request: 2,
    request: 3,
  }

  @doc ~S"""
  Performs a get request.

  For options see: `&request/3`.
  """
  @spec get(String.t, keyword) :: {:ok, Response.t} | {:error, term}
  def get(url, options \\ []), do: :get |> request(url, options)

  @doc ~S"""
  Performs a post request, passing the body in the options.

  For options see: `&request/3`.
  """
  @spec post(String.t, post_body, keyword)
   :: {:ok, Response.t} | {:error, term}
  def post(url, body, options \\ [])

  def post(url, {:urlencoded, body}, options) do
    body = URI.encode_query(body)
    options =
      options
      |> Keyword.update(:headers, [@post_header_urlencoded], &([@post_header_urlencoded | &1]))

    post(url, body, options)
  end

  def post(url, {:json, body}, options) do
    with {:ok, body} <- Poison.encode(body) do
      options =
        options
        |> Keyword.update(:headers, [@post_header_json], &([@post_header_json | &1]))

      post(url, body, options)
    else
      _error -> {:error, :body_not_valid_json}
    end
  end

  # Default
  def post(url, body, options),
    do: :post |> request(url, Keyword.put(options, :body, body))

  @doc ~S"""
  Performs a request.

  The given `method` is used and the `url` is called.

  The following options can be set:

    * `:body`, the body to send with the request.
    * `:params`, a map containing query params.
    * `:headers`, list of header tuples.
    * `:settings`, options to pass along to `:hackney`.
    * `:fail`, will error out any request with a non 2xx response code, when set to true.
    * `:auth`, set authorization options.
    * `:format`, set to parse. (Like `:json`)
  """
  @spec request(term, String.t, keyword) :: {:ok, Response.t} | {:error, term}
  def request(method, url, options \\ []) do
    full_url = generate_url(url, options)

    headers =
      options[:headers] || []

    body =
      options[:body] || ""

    hackney_settings =
      @default_settings
      |> Keyword.merge(options[:settings] || [])
      |> Kernel.++([:with_body])

    headers =
      case @auth_methods[options[:auth]] do
        nil -> headers
        method ->
          # 💖 Pipes
          method
          |> method.auth(full_url, headers, body, options)
          |> Kernel.++(headers)
      end

    method
    |> :hackney.request(full_url, headers, body, hackney_settings)
    |> parse_response(options[:format] || :text)
    |> handle_response(:fail in options)
  end

  ### Helpers ###

  defp generate_url(url, options) do
    full_url =
      cond do
        not Keyword.has_key?(options, :params) ->
          url
        URI.parse(url).query ->
          url <> "&" <> URI.encode_query(options[:params] || %{})
        true ->
          url <> "?" <> URI.encode_query(options[:params] || %{})
      end

    full_url
    |> to_string
    |> default_process_url
  end

  defp parse_response({:ok, status, resp_headers, resp_body}, format) do
    with {:ok, body} <- parse_body(resp_body, format) do
      response =
        %Response{
          status: status,
          headers: resp_headers,
          body: body,
        }

      {:ok, response}
    else
      error -> error
    end
  end

  defp parse_response({:ok, status, resp_headers}, format) do
    parse_response({:ok, status, resp_headers, ""}, format)
  end

  defp parse_response(error, _format) do
    error
  end

  defp parse_body(body, format)

  defp parse_body(body, :text), do: {:ok, body}
  defp parse_body(body, :json), do: body |> Poison.decode
  defp parse_body(body, :json_atoms), do: body |> Poison.decode(keys: :atoms)
  defp parse_body(body, :json_atoms!), do: body |> Poison.decode(keys: :atoms!)

  defp handle_response({:ok, %{status: status}}, true)
    when status < 200 or status >= 300, do: {:error, :http_status_failure}
  defp handle_response(response, _), do: response

  defp default_process_url(url) do
    case url |> String.slice(0, 12) |> String.downcase do
      "http://" <> _ -> url
      "https://" <> _ -> url
      "http+unix://" <> _ -> url
      _ -> "http://" <> url
    end
  end

  ## Bangified ###

  @doc ~S"""
  Performs a get request.

  For options see: `&get/2`.
  """
  @spec get!(String.t, keyword) :: Response.t
  def get!(url, options \\ []) do
    case request(:get, url, options) do
      {:ok, response} -> response
      {:error, reason} ->
        context =
          [
            url: url,
            options: options,
          ]

        raise RequestError.exception(reason, nil, context)
    end
  end

  @doc ~S"""
  Performs a post request, passing the body in the options.

  For options see: `&post/3`.
  """
  @spec post!(String.t, post_body, keyword) :: Response.t
  def post!(url, body, options \\ []) do
    case post(url, body, options) do
      {:ok, response} -> response
      {:error, reason} ->
        context =
          [
            url: url,
            body: body,
            options: options,
          ]

        raise RequestError.exception(reason, nil, context)
    end
  end
end
