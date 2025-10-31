defmodule Filtr.LiveView do
  @moduledoc """
    Provides Phoenix LiveView integration with attr-style parameter definitions.
  """

  @valid_error_modes [:strict, :fallback, :raise]

  defmacro __using__(opts \\ []) do
    error_mode = Keyword.get(opts, :error_mode, :fallback)

    if !(error_mode in @valid_error_modes or is_function(error_mode)) do
      raise ArgumentError, "error_mode must be one of: #{inspect(@valid_error_modes)}"
    end

    quote do
      import Filtr.LiveView, only: [param: 2, param: 3, param: 4]

      alias Phoenix.LiveView.Socket

      Module.register_attribute(__MODULE__, :filtr_params, accumulate: true)
      @filtr_error_mode unquote(error_mode)
      @before_compile Filtr.LiveView

      on_mount({__MODULE__, :filtr_params})

      def on_mount(:filtr_params, params, _session, socket) do
        {:cont, do_filtr_param_on_mount(socket, params)}
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
      @filtr_params {unquote(name), [type: unquote(type), validators: unquote(validators)] ++ unquote(opts)}
    end
  end

  defmacro __before_compile__(env) do
    filtr_params = Module.get_attribute(env.module, :filtr_params, [])

    if Enum.empty?(filtr_params) do
      quote do
        # No params defined, generate empty functions
        def do_filtr_param_on_mount(socket, _params), do: socket
      end
    else
      filtr_schema = Map.new(filtr_params)

      quote do
        defp do_filtr_param_on_mount(socket, params) do
          filtr_params = Filtr.run(unquote(Macro.escape(filtr_schema)), params, error_mode: @filtr_error_mode)

          socket =
            socket
            |> Phoenix.Component.assign(filtr: filtr_params)
            |> Phoenix.LiveView.attach_hook(:filtr, :handle_params, &handle_filtr_params/3)
        end

        defp handle_filtr_params(params, _uri, socket) do
          filtr_params = Filtr.run(unquote(Macro.escape(filtr_schema)), params, error_mode: @filtr_error_mode)
          {:cont, Phoenix.Component.assign(socket, filtr: filtr_params)}
        end
      end
    end
  end
end
