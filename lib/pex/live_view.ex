defmodule Pex.LiveView do
  @moduledoc """
  Provides Phoenix LiveView integration for parameter parsing and validation.

  This module enables seamless parameter handling in LiveViews by automatically
  parsing and validating parameters during mount and handle_params lifecycle events.

  ## Usage

  To use Pex with LiveViews, add it to your LiveView module:

      defmodule MyAppWeb.SearchLive do
        use MyAppWeb, :live_view
        use Pex.LiveView, schema: %{
          q: [type: :string, default: ""],
          page: [type: :integer, default: 1, min: 1],
          filters: [type: {:list, :string}, default: []]
        }

        def mount(_params, _session, socket) do
          {:ok, socket}
        end

        def handle_params(_params, _uri, socket) do
          # Access validated params with socket.assigns.pex
          search_query = socket.assigns.pex.q
          current_page = socket.assigns.pex.page
          {:noreply, socket}
        end
      end

  ## Options

  - `:schema` - The parameter schema definition (required)
  - `:error_mode` - Controls error handling behavior (`:strict`, `:fallback`, `:raise`, or `function`)

  ## Parameter Access

  Validated parameters are available in `socket.assigns.pex`. The parameters are
  automatically parsed and validated during both the initial mount and subsequent
  parameter changes via `handle_params/3`.

  ## Example

      # Basic LiveView with parameter validation
      defmodule MyAppWeb.ProductsLive do
        use MyAppWeb, :live_view
        use Pex.LiveView, schema: %{
          category: [type: :string, default: "all"],
          sort: [type: :string, in: ["name", "price"], default: "name"],
          page: [type: :integer, default: 1, min: 1]
        }

        def handle_params(_params, _uri, socket) do
          products = load_products(socket.assigns.pex)
          {:noreply, assign(socket, products: products)}
        end

        defp load_products(params) do
          # params.category, params.sort, and params.page are validated
          MyApp.Products.list_products(params)
        end
      end

  ## Error Handling

  By default, invalid parameters will cause errors. Use `:error_mode` option to
  control error handling:

      use Pex.LiveView,
        schema: %{search: [type: :string, default: ""]},
        error_mode: :fallback
  """

  alias Phoenix.LiveView.Socket
  alias Phoenix.Component

  defmacro __using__(opts) do
    schema = Keyword.get(opts, :schema) || raise "schema is required"
    error_mode = Keyword.get(opts, :error_mode, :strict)

    quote do
      @pex_schema unquote(schema)

      @spec on_mount(:pex_params, map(), map(), Socket.t()) :: {:cont, Socket.t()}
      def on_mount(:pex_params, params, _session, socket) do
        pex_params = Pex.run(@pex_schema, params, error_mode: unquote(error_mode))

        socket =
          socket
          |> assign(pex: pex_params)
          |> attach_hook(socket, :handle_params, &handle_pex_params/3)

        {:cont, socket}
      end

      on_mount({__MODULE__, :pex_params})

      defp handle_pex_params(params, _uri, socket) do
        pex_params = Pex.run(@pex_schema, params, error_mode: unquote(error_mode))
        {:cont, Component.assign(socket, pex: pex_params)}
      end
    end
  end

end
