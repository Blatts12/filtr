defmodule Pex.LiveView do
  @moduledoc false

  @valid_error_modes [:strict, :fallback, :raise]

  defmacro __using__(opts \\ []) do
    error_mode = Keyword.get(opts, :error_mode, :fallback)

    if !(error_mode in @valid_error_modes or is_function(error_mode)) do
      raise ArgumentError, "error_mode must be one of: #{inspect(@valid_error_modes)} or a function"
    end

    quote do
      import Pex.LiveView, only: [param: 2, param: 3, param: 4]

      alias Phoenix.LiveView.Socket

      Module.register_attribute(__MODULE__, :pex_params, accumulate: true)
      @pex_error_mode unquote(error_mode)
      @before_compile Pex.LiveView

      on_mount({__MODULE__, :pex_params})

      @spec on_mount(:pex_params, map(), map(), Socket.t()) :: {:cont, Socket.t()}
      def on_mount(:pex_params, params, _session, socket) do
        {:cont, do_pex_param_on_mount(socket, params)}
      end
    end
  end

  @doc """
  Defines a parameter with its type and validation options.

  ## Examples

      param :name, :string
      param :age, :integer, default: 18, min: 0, max: 120
      param :email, :string, required: true, pattern: ~r/@/
      param :tags, {:list, :string}, default: []
  """
  defmacro param(name, type, validators \\ [], opts \\ []) do
    quote do
      @pex_params {unquote(name), [type: unquote(type), validators: unquote(validators)] ++ unquote(opts)}
    end
  end

  defmacro __before_compile__(env) do
    pex_params = Module.get_attribute(env.module, :pex_params, [])

    if Enum.empty?(pex_params) do
      quote do
        # No params defined, generate empty functions
        def do_pex_param_on_mount(socket, _params), do: socket
      end
    else
      pex_schema = Map.new(pex_params)

      quote do
        defp do_pex_param_on_mount(socket, params) do
          pex_params = Pex.run(unquote(Macro.escape(pex_schema)), params, error_mode: @pex_error_mode)

          socket =
            socket
            |> Phoenix.Component.assign(pex: pex_params)
            |> Phoenix.LiveView.attach_hook(:pex, :handle_params, &handle_pex_params/3)
        end

        defp handle_pex_params(params, _uri, socket) do
          pex_params = Pex.run(unquote(Macro.escape(pex_schema)), params, error_mode: @pex_error_mode)
          {:cont, Phoenix.Component.assign(socket, pex: pex_params)}
        end
      end
    end
  end
end
