defmodule Pex.LiveView do
  alias Phoenix.LiveView.Socket
  alias Phoenix.Component

  defmacro __using__(_opts) do
    quote do
      import Pex.LiveView

      # @query_params_schema unquote(schema)
      @query_params_schema %{}
      @query_params_schema_keys Map.keys(@query_params_schema)

      @spec on_mount(:query_params, map(), map(), Socket.t()) :: {:cont, Socket.t()}
      def on_mount(:query_params, params, _session, socket) do
        params = cast_params(params, @query_params_schema)

        socket =
          socket
          |> assign(params)
          |> attach_hook(socket, :handle_params, &handle_query_params/3)

        {:cont, socket}
      end

      on_mount({__MODULE__, :query_params})

      defp handle_query_params(params, _uri, socket) do
        params = cast_params(socket, params, @query_params_schema)
        {:cont, Component.assign(socket, params)}
      end

      defp params(%{assigns: assigns}), do: Map.take(assigns, @query_params_schema_keys)
      defp params(assigns), do: Map.take(assigns, @query_params_schema_keys)

      defp put_param(assigns, key, value) do
        params = params(assigns)
        Map.put(params, key, value)
      end

      defp delete_param(assigns, key) do
        params = params(assigns)
        Map.delete(params, key)
      end

      defp drop_params(assigns, keys) do
        params = params(assigns)
        Map.drop(params, keys)
      end

      defp update_param(assigns, key, default, update_fn) do
        params = params(assigns)
        Map.update(params, key, default, update_fn)
      end
    end
  end

  @spec cast_params(socket :: map(), params :: map(), schema :: map()) :: map()
  def cast_params(%{assigns: assigns}, params, schema) do
    Map.new(schema, fn {key, type} ->
      default = type[:default]
      cast_fn = type[:cast_fn]
      value = assigns |> get_value(params, key) |> cast_value(cast_fn)
      type = Keyword.put(type, :required, true)

      case Valdi.validate(value, type) do
        :ok -> {key, value}
        {:error, _} -> {key, if(is_function(default), do: default.(), else: default)}
      end
    end)
  end

  @spec cast_params(params :: map(), schema :: map()) :: map()
  def cast_params(params, schema) do
    params = Map.new(params, fn {k, v} -> {to_string(k), v} end)

    Map.new(schema, fn {key, type} ->
      default = type[:default]
      cast_fn = type[:cast_fn]
      value = cast_value(params[to_string(key)], cast_fn)

      case Valdi.validate(value, type) do
        :ok -> {key, if(is_nil(value), do: handle_default(default), else: value)}
        {:error, _} -> {key, handle_default(default)}
      end
    end)
  end

  defp get_value(assigns, params, key) do
    case Map.get(params, to_string(key)) do
      nil -> Map.get(assigns, key)
      value -> value
    end
  end

  defp cast_value(value, cast_fn) when is_function(cast_fn, 1) do
    case cast_fn.(value) do
      {:ok, value} -> value
      {:error, _error} -> nil
      :error -> nil
      value -> value
    end
  end

  defp cast_value(value, _), do: value

  defp handle_default(default) when is_function(default, 0), do: default.()
  defp handle_default(default), do: default

  @spec cast_date(any()) :: {:ok, Date.t()} | {:error, binary() | atom()}
  def cast_date(nil), do: {:error, :required}
  def cast_date(%Date{} = date), do: {:ok, date}
  def cast_date(date), do: Date.from_iso8601(date)

  @spec cast_datetime(any()) :: {:ok, DateTime.t()} | {:error, binary() | atom()}
  def cast_datetime(nil), do: {:error, :required}
  def cast_datetime(%DateTime{} = datetime), do: {:ok, datetime}
  def cast_datetime(datetime), do: DateTime.from_iso8601(datetime)
end
