if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Filtr.LiveView do
    @moduledoc """
    Phoenix LiveView integration, with URL parameters declared once per LiveView.

    A LiveView reads the same query params on mount and again on every navigation, and
    that check tends to get copied between `mount/3` and `handle_params/3`. Declare the
    params here instead, and the validated result is waiting in the assigns.

    This module only exists when `Phoenix.LiveView` is available, and it assumes you know
    the schema fields from `Filtr`.

    ## Declaring params

    Unlike `Filtr.Controller`, params belong to the LiveView as a whole, not to a single
    function. Declare them anywhere in the module.

        defmodule MyAppWeb.SearchLive do
          use MyAppWeb, :live_view
          use Filtr.LiveView, error_mode: :fallback

          param :query, :string, default: ""
          param :limit, :integer, default: 10, min: 1, max: 100

          param :filters do
            param :category, :string, default: "all"
            param :sort, :string, in: ["name", "date"], default: "name"
          end

          def mount(_params, _session, socket) do
            # socket.assigns.filtr.query, .limit, .filters.sort
            {:ok, socket}
          end
        end

    Nested blocks and `param name, :list do ... end` work exactly as they do in
    `Filtr.Controller`.

    ## How the params reach the socket

    Filtr adds an `on_mount` hook that validates the mount params and assigns the result
    as `:filtr`, then attaches a `handle_params` hook that revalidates on every navigation
    and reassigns. Your own `handle_params/3` still runs and receives the raw params, so
    read `socket.assigns.filtr` when you want the validated ones.

    The assign is always a map with a `_valid?` flag, which is what you check in `:strict`
    mode:

        def mount(_params, _session, socket) do
          if socket.assigns.filtr._valid? do
            {:ok, load(socket)}
          else
            {:ok, put_flash(socket, :error, "Bad search link")}
          end
        end

    ## Error modes

    `error_mode:` accepts `:fallback`, `:strict` or `:raise` only, and defaults to
    `:fallback`. Unlike `Filtr.Controller`, it ignores the app-wide
    `config :filtr, error_mode: mode`, so set it explicitly if your app uses a different
    default. Custom error handler functions are not supported here either, because there
    is no connection to hand back.

    Think twice before choosing `:raise`. Params come from the URL, which anyone can edit,
    and a raise there takes down the LiveView process on mount instead of showing the
    person something useful.

    ## Lists in the URL

    Phoenix parses `users[0][name]=John&users[1][name]=Jane` into a map keyed by index,
    and Filtr converts it back to a list, sorted by that index. Nothing else in the URL
    guarantees order, so an unindexed list of params comes back in whatever order the map
    gives.
    """
    alias Filtr.Helpers

    @valid_error_modes [:strict, :fallback, :raise]

    defmacro __using__(opts \\ []) do
      error_mode = Keyword.get(opts, :error_mode, :fallback)

      if error_mode not in @valid_error_modes do
        raise ArgumentError, "error_mode must be one of: #{inspect(@valid_error_modes)}"
      end

      quote do
        import Filtr, only: [collect_errors: 1]
        import Filtr.LiveView, only: [param: 2, param: 3]

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

    defmacro param(name, do: nested_block) do
      nested_schema = Helpers.render_ast_to_schema(nested_block)

      quote do
        @filtr_params {unquote(name), %{type: unquote(Macro.escape(nested_schema))}}
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
    defmacro param(name, type, opts \\ [])

    defmacro param(name, :list, do: nested_block) do
      nested_schema = Helpers.render_ast_to_schema(nested_block)

      quote do
        @filtr_params {unquote(name), %{type: {:list, unquote(Macro.escape(nested_schema))}}}
      end
    end

    defmacro param(name, type, opts) do
      quote do
        @filtr_params {unquote(name), unquote(opts) |> Keyword.put(:type, unquote(type)) |> Helpers.parse_param_opts()}
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
        filtr_schema =
          Map.new(filtr_params, fn {key, opts_or_schema} ->
            {
              key,
              if(is_map(opts_or_schema),
                do: opts_or_schema,
                else: Helpers.parse_param_opts(opts_or_schema)
              )
            }
          end)

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
end
