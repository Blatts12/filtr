defmodule Filtr.Controller do
  @moduledoc """
  Phoenix controller integration, with parameters declared per action.

  You declare what an action expects with `param/2` and `param/3`, in the style of the
  `attr` macro from Phoenix Components. The params each action receives are then already
  cast and validated, so the action body can get on with its job.

  This guide assumes you know the schema fields from `Filtr`, since `param` is a shorthand
  for them.

  ## Declaring params

  Every `param` call attaches to the next function you define, and the list resets after
  it. Declare params directly above the action they belong to.

      defmodule MyAppWeb.UserController do
        use MyAppWeb, :controller
        use Filtr.Controller

        param :name, :string, required: true
        param :age, :integer, min: 18

        def create(conn, params) do
          # params.name is a string, params.age is an integer of at least 18
          json(conn, %{message: "User \#{params.name} created"})
        end

        param :q, :string, default: ""
        param :page, :integer, default: 1, min: 1

        def search(conn, params) do
          json(conn, %{query: params.q, page: params.page})
        end
      end

  The options split themselves. `:type`, `:required`, `:default` and `:error_mode` are
  schema fields, and everything else becomes a validator, which is why `min: 18` sits
  next to `required: true` with no extra nesting.

  Params arrive as a map with atom keys and a `_valid?` flag, the same result
  `Filtr.run/3` returns.

  ## Nested params and lists

  A `param` with a block declares a nested map, and `param name, :list` with a block
  declares a list of them. Blocks may contain `param` calls only, and nest as deep as you
  like.

      param :filters do
        param :q, :string, default: ""
        param :category, :string, in: ["books", "movies"], default: "books"
      end

      param :items, :list do
        param :name, :string, required: true
        param :quantity, :integer, min: 1, default: 1
      end

      def order(conn, params) do
        # params.filters.category, and params.items as a list of maps
        json(conn, %{items: params.items})
      end

  ## Error modes

  Pass `error_mode:` to `use` for the whole controller, and override it on single params
  when one field deserves different treatment.

      use Filtr.Controller, error_mode: :strict

      param :query, :string, required: true
      param :page, :integer, default: 1, error_mode: :fallback

  Without the option, the controller uses the app-wide default from
  `config :filtr, error_mode: mode`, which is `:fallback`. See `Filtr` for what the three
  modes do.

  ## Custom error handlers

  Instead of a mode, `error_mode:` accepts a function of arity 2 that takes the connection
  and the validated params. The controller then runs in `:strict` mode internally, and
  your handler is called only when `params._valid?` is `false`. When everything validates,
  the action runs as usual.

      defmodule MyAppWeb.ErrorHandler do
        def handle(conn, params) do
          conn
          |> Plug.Conn.put_status(:bad_request)
          |> Phoenix.Controller.json(%{errors: Filtr.collect_errors(params)})
          |> Plug.Conn.halt()
        end
      end

      defmodule MyAppWeb.UserController do
        use MyAppWeb, :controller
        use Filtr.Controller, error_mode: &MyAppWeb.ErrorHandler.handle/2

        param :name, :string, required: true

        def create(conn, params) do
          json(conn, %{message: "User \#{params.name} created"})
        end
      end

  A function capture, an MFA tuple such as `{MyAppWeb.ErrorHandler, :handle, 2}`, and an
  inline anonymous function all work. Anything else raises an `ArgumentError` at compile
  time.

  A handler keeps error responses in one place, at the cost of taking the decision away
  from the action. When a specific action wants to answer differently, give it `:strict`
  and read `_valid?` yourself.

  ## What the macro generates

  Filtr defines a wrapper around each action that has params, using `defoverridable` and
  `super`. That means an action is validated once, and two things follow. Params are only
  picked up on functions defined with `def` that take two arguments, and a plug that runs
  before the action still sees the raw params from Phoenix.
  """

  alias Filtr.Helpers

  # credo:disable-for-this-file Credo.Check.Design.AliasUsage

  defmacro __using__(opts \\ []) do
    error_mode = Keyword.get(opts, :error_mode) || Helpers.default_error_mode()

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
          Helpers.supported_error_mode?(error_mode)
      end

    if not supported_error_mode? do
      raise ArgumentError,
            "error_mode must be one of: #{inspect(Helpers.supported_error_modes())} or function with MFA, function capture or anonymous function with arity 2"
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
    nested_schema = Helpers.render_ast_to_schema(nested_block)

    quote do
      @filtr_param_definitions {unquote(name), %{type: unquote(Macro.escape(nested_schema))}}
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
    nested_schema = Helpers.render_ast_to_schema(nested_block)

    quote do
      @filtr_param_definitions {unquote(name), %{type: {:list, unquote(Macro.escape(nested_schema))}}}
    end
  end

  defmacro param(name, type, opts) when is_list(opts) do
    quote do
      @filtr_param_definitions {unquote(name),
                                unquote(opts)
                                |> Keyword.put(:type, unquote(type))
                                |> Helpers.parse_param_opts()}
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
              if(is_map(opts_or_schema),
                do: opts_or_schema,
                else: Helpers.parse_param_opts(opts_or_schema)
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
    error_mode = Module.get_attribute(env.module, :filtr_error_mode) || Helpers.default_error_mode()

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
