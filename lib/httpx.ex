defmodule HTTPX do
  @moduledoc ~S"""
  Simple HTTP(s) client with integrated auth methods.
  """
  use HTTPX.Log
  alias HTTPX.{Request, RequestError, Response}

  @type post_body ::
          String.t() | {:urlencoded, map | keyword} | {:json, map | keyword | String.t()}

  @post_header_urlencoded {"Content-Type", "application/x-www-form-urlencoded"}
  @post_header_json {"Content-Type", "application/json"}
  @post_header_file {"Content-Type", "application/octet-stream"}

  @content_encoding_gzip {"Content-Encoding", "gzip"}
  @content_encoding_compress {"Content-Encoding", "compress"}
  @content_encoding_deflate {"Content-Encoding", "deflate"}
  @content_encoding_br {"Content-Encoding", "br"}

  @dialyzer {
    [:no_return, :no_match, :nowarn_function],
    get: 1, get: 2, request: 2, request: 3
  }

  @doc ~S"""
  Performs a get request.

  For options see: `&request/3`.
  """
  @spec get(String.t(), keyword) :: {:ok, Response.t()} | {:error, term}
  def get(url, options \\ []), do: :get |> request(url, options)

  @doc ~S"""
  Performs a post request, passing the body in the options.

  For options see: `&request/3`.
  """
  @spec post(String.t(), post_body, keyword) :: {:ok, Response.t()} | {:error, term}
  def post(url, body, options \\ []) do
    with {:ok, opts} <- body_encoding(body, options) do
      request(:post, url, opts)
    end
  end

  @doc ~S"""
  Performs a patch request, passing the body in the options.

  For options see: `&request/3`.
  """
  @spec patch(String.t(), post_body, keyword) :: {:ok, Response.t()} | {:error, term}
  def patch(url, body, options \\ []) do
    with {:ok, opts} <- body_encoding(body, options) do
      request(:patch, url, opts)
    end
  end

  @doc ~S"""
  Performs a put request, passing the body in the options.

  For options see: `&request/3`.
  """
  @spec put(String.t(), post_body, keyword) :: {:ok, Response.t()} | {:error, term}
  def put(url, body, options \\ []) do
    with {:ok, opts} <- body_encoding(body, options) do
      request(:put, url, opts)
    end
  end

  @doc ~S"""
  Performs a delete request.

  For options see: `&request/3`.
  """
  @spec delete(String.t(), keyword) :: {:ok, Response.t()} | {:error, term}
  def delete(url, options \\ []), do: request(:delete, url, options)

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
    * `:retry`, set to retry the request. See the retry options.
  """
  @spec request(term, String.t(), keyword) :: {:ok, Response.t()} | {:error, term}
  def request(method, url, options \\ []) do
    method
    |> Request.prepare(url, options)
    |> perform()
  end

  @doc ~S"""
  Perform a given request.
  """
  @spec perform(HTTPX.Request.t()) :: {:ok, HTTPX.Response.t()} | {:error, term}
  def perform(request) do
    %{
      method: m,
      url: u,
      body: b,
      headers: h,
      settings: s,
      format: format,
      fail: fail
    } = __MODULE__.Process.pre_request(request)

    Log.log(m, u, h, b)
    response = :hackney.request(m, u, h, b, s)
    Log.log(m, u, h, b, response)

    case response
         |> __MODULE__.Process.post_request()
         |> parse_response(format, s)
         |> handle_response(fail) do
      {:ok, response} -> __MODULE__.Process.post_parse(response)
      error -> error
    end
  end

  @doc ~S"""
  Performs a request on all IPs associated with the host DNS.

  For more information see: `request/3`.
  """
  @spec multi_request(term, String.t(), keyword) :: %{ok: map, error: map}
  def multi_request(method, url, opts \\ []) do
    uri = %{host: host} = URI.parse(url)
    opts = Keyword.update(opts, :headers, [{"Host", host}], &[{"Host", host} | &1])

    host
    |> String.to_charlist()
    |> :inet_res.lookup(:in, :a)
    |> Enum.map(&(&1 |> Tuple.to_list() |> Enum.join(".")))
    |> Enum.map(&{&1, request(method, to_string(%{uri | host: &1}), opts)})
    |> Enum.group_by(&elem(elem(&1, 1), 0))
    |> Enum.into(%{})
    |> Map.update(:ok, [], &Enum.into(&1, %{}, fn {ip, r} -> {ip, elem(r, 1)} end))
    |> Map.update(:error, [], &Enum.into(&1, %{}))
  end

  ### Helpers ###

  defp parse_response({:ok, status, resp_headers, resp_body}, format, opts) do
    case parse_body(resp_body, format, opts) do
      {:ok, body} ->
        {:ok,
         %Response{
           status: status,
           headers: resp_headers,
           body: body
         }}

      error ->
        error
    end
  end

  defp parse_response({:ok, status, resp_headers}, format, opts) do
    parse_response({:ok, status, resp_headers, ""}, format, opts)
  end

  defp parse_response(error, _format, _opts), do: error

  defp parse_body(body, format, opts)

  defp parse_body(body, :text, _opts), do: {:ok, body}
  defp parse_body(body, :json, _opts), do: body |> Jason.decode()
  defp parse_body(body, :json_atoms, _opts), do: body |> Jason.decode(keys: :atoms)
  defp parse_body(body, :json_atoms!, _opts), do: body |> Jason.decode(keys: :atoms!)

  defp parse_body(body, :stream, opts) do
    stream_opts = opts[:stream] || []

    with {:ok, streamer} <- create_stream_splitter(stream_opts[:format] || :chunked, stream_opts) do
      {:ok, Stream.resource(fn -> {body, <<>>} end, streamer, fn _ref -> :ok end)}
    end
  end

  defp create_stream_splitter(:chunks, _opts) do
    {:ok,
     fn {ref, _buffer} ->
       case :hackney.stream_body(ref) do
         {:ok, chunk} -> {[chunk], {ref, nil}}
         :done -> {:halt, ref}
         {:error, reason} -> raise "Error reading HTTP stream. (#{inspect(reason)})"
       end
     end}
  end

  defp create_stream_splitter(:newline, opts) do
    create_stream_splitter(:separated, Keyword.merge(opts, separator: ~r/\r?\n/, ends_with: "\n"))
  end

  # credo:disable-for-next-line
  defp create_stream_splitter(:separated, opts) do
    if separator = opts[:separator] do
      ends_with? =
        cond do
          e = opts[:ends_with] ->
            &String.ends_with?(&1, e)

          is_binary(separator) ->
            &String.ends_with?(&1, separator)

          Regex.regex?(separator) ->
            source = Regex.source(separator)

            if Regex.escape(source) == source do
              &String.ends_with?(&1, source)
            else
              &Regex.match?(Regex.compile!(source <> "$"), &1)
            end
        end

      {:ok,
       fn {ref, buffer} ->
         case :hackney.stream_body(ref) do
           {:ok, chunk} ->
             items = String.split(buffer <> chunk, separator, trim: true)

             if ends_with?.(chunk) do
               {items, {ref, <<>>}}
             else
               {buffer, items} = List.pop_at(items, -1)
               {items, {ref, buffer}}
             end

           :done ->
             {:halt, ref}

           {:error, reason} ->
             raise "Error reading HTTP stream. (#{inspect(reason)})"
         end
       end}
    else
      {:error, :stream_missing_separator}
    end
  end

  defp create_stream_splitter(_, _), do: {:error, :invalid_stream_format}

  defp handle_response({:ok, %{status: status}}, true)
       when status < 200 or status >= 300,
       do: {:error, :http_status_failure}

  defp handle_response(response, _), do: response

  ### Query Encoding ###

  @doc ~S"""
  Encode a map as query.
  """
  @spec query_encode(map) :: binary
  def query_encode(data) do
    data
    |> query_encode("")
    |> query_encode_to_binary()
  end

  defp query_encode(data, prefix) do
    Enum.flat_map(data, fn {field, value} ->
      key =
        if prefix == "",
          do: URI.encode_www_form(to_string(field)),
          else: [prefix, ?[, URI.encode_www_form(to_string(field)), ?]]

      if is_map(value) or is_list(value) do
        query_encode(value, key)
      else
        [?&, key, ?=, URI.encode_www_form(to_string(value))]
      end
    end)
  end

  defp query_encode_to_binary([?& | data]), do: IO.iodata_to_binary(data)
  defp query_encode_to_binary(data), do: IO.iodata_to_binary(data)

  defp body_encoding({:urlencoded, body}, options) do
    {:ok,
     options
     |> Keyword.update(:headers, [@post_header_urlencoded], &[@post_header_urlencoded | &1])
     |> Keyword.put(:body, query_encode(body))
     |> body_maybe_compress(options[:compress])}
  end

  defp body_encoding({:file, body}, options) do
    {:ok,
     options
     |> Keyword.update(:headers, [@post_header_file], &[@post_header_file | &1])
     |> Keyword.put(:body, body)
     |> body_maybe_compress(options[:compress])}
  end

  defp body_encoding({:json, body}, options) do
    case Jason.encode(body) do
      {:ok, body} ->
        {:ok,
         options
         |> Keyword.update(:headers, [@post_header_json], &[@post_header_json | &1])
         |> Keyword.put(:body, body)
         |> body_maybe_compress(options[:compress])}

      _error ->
        {:error, :body_not_valid_json}
    end
  end

  defp body_encoding({:multipart, data}, options) do
    body =
      Enum.map(
        data,
        fn
          {name, {:file, file}} -> {:file, file, name, []}
          {name, {:file, file, headers}} -> {:file, file, name, headers}
          {name, {:binfile, data}} -> encode_mp_binfile(name, data)
          {name, {:binfile, data, opts}} -> encode_mp_binfile(name, data, opts)
          {name, value} -> {name, value}
        end
      )

    {:ok,
     options |> Keyword.put(:body, {:multipart, body}) |> body_maybe_compress(options[:compress])}
  end

  defp body_encoding(body, options),
    do: {:ok, Keyword.put(options, :body, body) |> body_maybe_compress(options[:compress])}

  defp body_maybe_compress(options, compression)
  defp body_maybe_compress(options, compression) when compression in [nil, :identity], do: options

  defp body_maybe_compress(options, :gzip) do
    options
    |> Keyword.update(:headers, [@content_encoding_gzip], &[@content_encoding_gzip | &1])
    |> Keyword.update!(:body, &:zlib.gzip/1)
  end

  defp body_maybe_compress(options, :compress) do
    options
    |> Keyword.update(:headers, [@content_encoding_compress], &[@content_encoding_compress | &1])
    |> Keyword.update!(:body, &:zlib.compress/1)
  end

  defp body_maybe_compress(options, :deflate) do
    options
    |> Keyword.update(:headers, [@content_encoding_deflate], &[@content_encoding_deflate | &1])
    |> Keyword.update!(:body, &:zlib.compress/1)
  end

  defp body_maybe_compress(options, :br) do
    options
    |> Keyword.update(:headers, [@content_encoding_br], &[@content_encoding_br | &1])
    |> Keyword.update!(:body, &apply(:brotli, :encode, [&1]))
  rescue
    UndefinedFunctionError -> reraise "Missing `:brotli` dependency.", __STACKTRACE__
  end

  defp encode_mp_binfile(name, data, opts \\ []) do
    filename = opts[:filename] || name

    mime =
      cond do
        m = opts[:mime] -> m
        String.printable?(data) -> "text/plain"
        :fallback -> "application/octet-stream"
      end

    {name, data, {"form-data", [{"name", "\"#{name}\""}, {"filename", "\"#{filename}\""}]},
     [{"content-type", mime}]}
  end

  ## Bangified ###

  @doc ~S"""
  Performs a get request.

  For options see: `&get/2`.
  """
  @spec get!(String.t(), keyword) :: Response.t() | no_return
  def get!(url, options \\ []) do
    case request(:get, url, options) do
      {:ok, response} ->
        response

      {:error, reason} ->
        context = [
          url: url,
          options: options
        ]

        raise RequestError.exception(reason, nil, context)
    end
  end

  @doc ~S"""
  Performs a post request, passing the body in the options.

  For options see: `&post/3`.
  """
  @spec post!(String.t(), post_body, keyword) :: Response.t() | no_return
  def post!(url, body, options \\ []) do
    case post(url, body, options) do
      {:ok, response} ->
        response

      {:error, reason} ->
        context = [
          url: url,
          body: body,
          options: options
        ]

        raise RequestError.exception(reason, nil, context)
    end
  end

  @doc ~S"""
  Performs a patch request, passing the body in the options.

  For options see: `&patch/3`.
  """
  @spec patch!(String.t(), post_body, keyword) :: Response.t() | no_return
  def patch!(url, body, options \\ []) do
    case patch(url, body, options) do
      {:ok, response} ->
        response

      {:error, reason} ->
        context = [
          url: url,
          body: body,
          options: options
        ]

        raise RequestError.exception(reason, nil, context)
    end
  end

  @doc ~S"""
  Performs a post request, passing the body in the options.

  For options see: `&put/3`.
  """
  @spec put!(String.t(), post_body, keyword) :: Response.t() | no_return
  def put!(url, body, options \\ []) do
    case put(url, body, options) do
      {:ok, response} ->
        response

      {:error, reason} ->
        context = [
          url: url,
          body: body,
          options: options
        ]

        raise RequestError.exception(reason, nil, context)
    end
  end

  @doc ~S"""
  Performs a delete request.

  For options see: `&delete/2`.
  """
  @spec delete!(String.t(), keyword) :: Response.t() | no_return
  def delete!(url, options \\ []) do
    case request(:delete, url, options) do
      {:ok, response} ->
        response

      {:error, reason} ->
        context = [
          url: url,
          options: options
        ]

        raise RequestError.exception(reason, nil, context)
    end
  end

  ## Optimize Process On Load ##

  @on_load :optimize

  @doc ~S"""
  Optimize HTTPX processors.

  This is automatically called on HTTPX load.
  So there is no need to call it manually.

  The function is idempotent, so there is no harm in calling it.
  """
  @spec optimize :: :ok
  def optimize, do: HTTPX.Process.optimize()
end
