defmodule Filtr.Controller do
  @moduledoc """
  Provides Phoenix Controller integration with attr-style parameter definitions.

  This module enables parameter handling in controllers using a syntax similar to Phoenix
  Components' `attr` macro, but using `param` to define parameters with validation per function.

  ## Usage

      defmodule MyAppWeb.UserController do
        use MyAppWeb, :controller
        use Filtr.Controller

        param :name, :string, required: true
        param :age, :integer, min: 18

        def create(conn, params) do
          # params.name is guaranteed to be a string
          # params.age is guaranteed to be an integer >= 18
          json(conn, %{message: "User \#{params.name} created"})
        end

        param :q, :string, default: ""
        param :page, :integer, default: 1, min: 1

        def search(conn, params) do
          # params.q is a string (defaults to "")
          # params.page is an integer >= 1 (defaults to 1)
          json(conn, %{query: params.q, page: params.page})
        end
      end
  """
  alias Filtr.Helpers

  @valid_error_modes [:strict, :fallback, :raise]

  defmacro __using__(opts \\ []) do
    error_mode = Keyword.get(opts, :error_mode, :fallback)

    if error_mode not in @valid_error_modes do
      raise ArgumentError, "error_mode must be one of: #{inspect(@valid_error_modes)}"
    end

    quote do
      import Filtr.Controller, only: [param: 2, param: 3]

      Module.register_attribute(__MODULE__, :filtr_param_definitions, accumulate: true)
      Module.register_attribute(__MODULE__, :filtr_function_params, accumulate: true)
      @filtr_error_mode unquote(error_mode)
      @on_definition Filtr.Controller
      @before_compile Filtr.Controller
    end
  end

  @doc """
  Defines a parameter with its type and validation options for the next controller function.

  ## Examples

      param :name, :string
      param :age, :integer, default: 18, min: 0, max: 120
      param :email, :string, required: true, pattern: ~r/@/
      param :tags, {:list, :string}, default: []
  """
  defmacro param(name, type, opts \\ []) do
    quote do
      @filtr_param_definitions {unquote(name), Keyword.put(unquote(opts), :type, unquote(type))}
    end
  end

  def __on_definition__(env, kind, name, args, _guards, _body) do
    if kind == :def and length(args) == 2 and not String.starts_with?(to_string(name), "__") do
      # This is likely a controller function
      param_definitions = Module.get_attribute(env.module, :filtr_param_definitions, [])

      if not Enum.empty?(param_definitions) do
        schema =
          Map.new(param_definitions, fn {key, opts} ->
            {key, Helpers.parse_param_opts(opts)}
          end)

        Module.put_attribute(env.module, :filtr_function_params, {name, schema})

        Module.delete_attribute(env.module, :filtr_param_definitions)
      end
    end
  end

  defmacro __before_compile__(env) do
    function_params = Module.get_attribute(env.module, :filtr_function_params, [])

    wrappers =
      for {function_name, schema} <- function_params do
        generate_wrapper(function_name, schema)
      end

    quote do
      (unquote_splicing(wrappers))
    end
  end

  defp generate_wrapper(function_name, schema) do
    quote do
      defoverridable [{unquote(function_name), 2}]

      def unquote(function_name)(conn, params) do
        validated_params = Filtr.run(unquote(Macro.escape(schema)), params, error_mode: @filtr_error_mode)
        super(conn, validated_params)
      end
    end
  end
end
