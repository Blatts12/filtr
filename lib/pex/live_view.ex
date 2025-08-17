defmodule Pex.LiveView do
  @moduledoc false

  alias Phoenix.LiveView.Socket
  alias Phoenix.Component

  defmacro __using__(opts) do
    schema = Keyword.get(opts, :schema) || raise "schema is required"
    no_errors? = Keyword.get(opts, :no_errors, false)

    quote do
      import Pex.LiveView

      @pex_schema unquote(schema)

      @spec on_mount(:pex_params, map(), map(), Socket.t()) :: {:cont, Socket.t()}
      def on_mount(:pex_params, params, _session, socket) do
        pex_params = Pex.run(@pex_schema, params, no_errors: unquote(no_errors?))

        socket =
          socket
          |> assign(pex: pex_params)
          |> attach_hook(socket, :handle_params, &handle_pex_params/3)

        {:cont, socket}
      end

      on_mount({__MODULE__, :pex_params})

      defp handle_pex_params(params, _uri, socket) do
        pex_params = Pex.run(@pex_schema, params, no_errors: unquote(no_errors?))
        {:cont, Component.assign(socket, pex: pex_params)}
      end
    end
  end

  defp params(%{assigns: assigns}), do: Map.get_lazy(assigns, :pex, &Pex.empty_pex_params/0)
  defp params(assigns), do: Map.get_lazy(assigns, :pex, &Pex.empty_pex_params/0)

  @spec put_param(Socket.t() | map(), atom(), any()) :: Pex.pex_params()
  def put_param(assigns, key, value) do
    params = params(assigns)
    Map.put(params, key, value)
  end

  @spec delete_param(Socket.t() | map(), atom()) :: Pex.pex_params()
  def delete_param(assigns, key) do
    params = params(assigns)
    Map.delete(params, key)
  end

  @spec drop_params(Socket.t() | map(), [atom()]) :: Pex.pex_params()
  def drop_params(assigns, keys) do
    params = params(assigns)
    Map.drop(params, keys)
  end

  @spec update_param(Socket.t() | map(), atom(), any(), (any() -> any())) :: Pex.pex_params()
  def update_param(assigns, key, default, update_fn) do
    params = params(assigns)
    Map.update(params, key, default, update_fn)
  end
end
