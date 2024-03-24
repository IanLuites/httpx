if Code.ensure_loaded?(OpenTelemetry.Tracer) do
  defmodule HTTPX.Telemetry do
    @moduledoc false

    require OpenTelemetry.SemanticConventions.Trace, as: Trace
    require OpenTelemetry.Tracer, as: Tracer

    defp http_method(:get), do: "GET"
    defp http_method(:head), do: "HEAD"
    defp http_method(:post), do: "POST"
    defp http_method(:patch), do: "PATCH"
    defp http_method(:put), do: "PUT"
    defp http_method(:delete), do: "DELETE"
    defp http_method(:connect), do: "CONNECT"
    defp http_method(:options), do: "OPTIONS"
    defp http_method(:trace), do: "TRACE"
    defp http_method(_), do: "_OTHER"

    @doc false
    def start_span(method, url) do
      uri = URI.parse(url)
      span_name = "HTTP " <> http_method(method)

      attrs = %{
        Trace.http_method() => http_method(method),
        Trace.http_url() => URI.to_string(%{uri | userinfo: nil}),
        Trace.http_target() => uri.path,
        Trace.net_host_name() => uri.host,
        Trace.http_scheme() => uri.scheme
      }

      parent_ctx = OpenTelemetry.Ctx.get_current()
      Process.put(:otel_parent_ctx, parent_ctx)

      Tracer.start_span(span_name, %{
        attributes: attrs,
        kind: :client
      })
      |> Tracer.set_current_span()

      propagator = :opentelemetry.get_text_map_injector()
      :otel_propagator_text_map.inject(propagator, [], &[{&1, &2} | &3])
    end

    @doc false
    def end_span(result) do
      case result do
        {:ok, %{status: status}} ->
          Tracer.set_attributes(%{Trace.http_status_code() => status})
          if status >= 400, do: Tracer.set_status(OpenTelemetry.status(:error, ""))

        {:error, exception = %{__exception__: true}} ->
          Tracer.set_status(OpenTelemetry.status(:error, Exception.message(exception)))

        error ->
          Tracer.set_status(OpenTelemetry.status(:error, inspect(error)))
      end

      Tracer.end_span()
      Process.delete(:otel_parent_ctx) |> OpenTelemetry.Ctx.attach()

      result
    end
  end
else
  defmodule HTTPX.Telemetry do
    @moduledoc false
    @doc false
    def start_span(_method, _url), do: []
    @doc false
    def end_span(result), do: result
  end
end
