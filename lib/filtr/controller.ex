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

  # credo:disable-for-this-file Credo.Check.Design.AliasUsage

  defmacro __using__(opts \\ []) do
    error_mode = Keyword.get(opts, :error_mode) || Filtr.Helpers.default_error_mode()

    supported_error_mode? =
      case error_mode do
        error_mode when is_function(error_mode, 2) ->
          # Function with arity 2
          true

        {_module, _function, 2} ->
          # MFA tuple: {Module, :function, 2}
          true

        {:&, _, [{:/, _, [_, 2]}]} ->
          # Function capture with arity 2: &func/2 or &Mod.func/2 (AST)
          true

        {:{}, _, [_module, _function, 2]} ->
          # MFA tuple: {Module, :function, 2} (AST)
          true

        {:fn, _, [{:->, _, [[_arg1, _arg2] | _]}]} ->
          # Anonymous function with arity 2 (AST)
          true

        error_mode ->
          Filtr.Helpers.supported_error_mode?(error_mode)
      end

    if not supported_error_mode? do
      raise ArgumentError,
            "error_mode must be one of: #{inspect(Filtr.Helpers.supported_error_modes())} or function with MFA, function capture or anonymous function with arity 2"
    end

    quote do
      import Filtr, only: [collect_errors: 1]
      import Filtr.Controller, only: [param: 2, param: 3]

      Module.register_attribute(__MODULE__, :filtr_param_definitions, accumulate: true)
      Module.register_attribute(__MODULE__, :filtr_function_params, accumulate: true)
      @filtr_error_mode unquote(Macro.escape(error_mode))
      @on_definition Filtr.Controller
      @before_compile Filtr.Controller
    end
  end

  defmacro param(name, do: nested_block) do
    nested_schema = Filtr.Helpers.render_ast_to_schema(nested_block)

    quote do
      @filtr_param_definitions {unquote(name), unquote(Macro.escape(nested_schema))}
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
  defmacro param(name, type, opts \\ [])

  defmacro param(name, :list, do: nested_block) do
    nested_schema = Filtr.Helpers.render_ast_to_schema(nested_block)

    quote do
      @filtr_param_definitions {unquote(name), [type: {:list, unquote(Macro.escape(nested_schema))}]}
    end
  end

  defmacro param(name, type, opts) when is_list(opts) do
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
          Map.new(param_definitions, fn {key, opts_or_schema} ->
            {
              key,
              # If opts_or_schema is a map, it's a nested schema
              if(is_map(opts_or_schema),
                do: opts_or_schema,
                else: Filtr.Helpers.parse_param_opts(opts_or_schema)
              )
            }
          end)

        Module.put_attribute(env.module, :filtr_function_params, {name, schema})

        Module.delete_attribute(env.module, :filtr_param_definitions)
      end
    end
  end

  defmacro __before_compile__(env) do
    function_params = Module.get_attribute(env.module, :filtr_function_params, [])
    error_mode = Module.get_attribute(env.module, :filtr_error_mode) || Filtr.Helpers.default_error_mode()

    wrappers =
      for {function_name, schema} <- function_params do
        generate_wrapper(function_name, schema, error_mode)
      end

    quote do
      (unquote_splicing(wrappers))
    end
  end

  defp generate_wrapper(function_name, schema, error_func) when is_function(error_func, 2) do
    # Function with arity 2
    quote do
      defoverridable [{unquote(function_name), 2}]

      def unquote(function_name)(conn, params) do
        validated_params = Filtr.run(unquote(Macro.escape(schema)), params, error_mode: :strict)

        if validated_params._valid? do
          super(conn, validated_params)
        else
          unquote(error_func).(conn, validated_params)
        end
      end
    end
  end

  defp generate_wrapper(function_name, schema, {module, function, 2}) do
    # MFA tuple
    quote do
      defoverridable [{unquote(function_name), 2}]

      def unquote(function_name)(conn, params) do
        validated_params = Filtr.run(unquote(Macro.escape(schema)), params, error_mode: :strict)

        if validated_params._valid? do
          super(conn, validated_params)
        else
          apply(unquote(module), unquote(function), [conn, validated_params])
        end
      end
    end
  end

  defp generate_wrapper(function_name, schema, {:&, _, [{:/, _, [_, 2]}]} = error_func) do
    # Function capture with arity 2 (AST)
    quote do
      defoverridable [{unquote(function_name), 2}]

      def unquote(function_name)(conn, params) do
        validated_params = Filtr.run(unquote(Macro.escape(schema)), params, error_mode: :strict)

        if validated_params._valid? do
          super(conn, validated_params)
        else
          unquote(error_func).(conn, validated_params)
        end
      end
    end
  end

  defp generate_wrapper(function_name, schema, {:{}, _, [module, function, 2]}) do
    # MFA tuple (AST)
    quote do
      defoverridable [{unquote(function_name), 2}]

      def unquote(function_name)(conn, params) do
        validated_params = Filtr.run(unquote(Macro.escape(schema)), params, error_mode: :strict)

        if validated_params._valid? do
          super(conn, validated_params)
        else
          apply(unquote(module), unquote(function), [conn, validated_params])
        end
      end
    end
  end

  defp generate_wrapper(function_name, schema, {:fn, _, [{:->, _, [[_arg1, _arg2] | _]}]} = error_func) do
    # Anonymous function with arity 2 (AST)
    quote do
      defoverridable [{unquote(function_name), 2}]

      def unquote(function_name)(conn, params) do
        validated_params = Filtr.run(unquote(Macro.escape(schema)), params, error_mode: :strict)

        if validated_params._valid? do
          super(conn, validated_params)
        else
          unquote(error_func).(conn, validated_params)
        end
      end
    end
  end

  defp generate_wrapper(function_name, schema, error_mode) do
    quote do
      defoverridable [{unquote(function_name), 2}]

      def unquote(function_name)(conn, params) do
        validated_params = Filtr.run(unquote(Macro.escape(schema)), params, error_mode: unquote(error_mode))
        super(conn, validated_params)
      end
    end
  end
end
