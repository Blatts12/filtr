defmodule Pex.LiveView do
  @moduledoc """
  Provides Phoenix LiveView integration for parameter parsing and validation.

  This module enables seamless parameter handling in LiveViews by automatically
  parsing and validating parameters during mount and handle_params lifecycle events.
  It also provides helper functions for parameter management within LiveViews.

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
  - `:no_errors` - When true, uses graceful fallback instead of raising errors

  ## Parameter Access

  Validated parameters are available in `socket.assigns.pex`. The parameters are
  automatically parsed and validated during both the initial mount and subsequent
  parameter changes via `handle_params/3`.

  ## Helper Functions

  This module provides several helper functions for managing parameters:

  - `put_param/3` - Add or update a single parameter
  - `delete_param/2` - Remove a parameter
  - `drop_params/2` - Remove multiple parameters
  - `update_param/4` - Update a parameter using a function

  ## Examples

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

      # Parameter manipulation
      def handle_event("filter_by_category", %{"category" => cat}, socket) do
        new_params = put_param(socket.assigns, :category, cat)
        {:noreply, assign(socket, pex: new_params)}
      end

  ## Error Handling

  By default, invalid parameters will cause errors. Use `:no_errors` option for
  graceful fallback to defaults:

      use Pex.LiveView,
        schema: %{search: [type: :string, default: ""]},
        no_errors: true
  """

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

  @doc """
  Adds or updates a parameter in the current parameter map.

  This function creates a new parameter map with the specified key-value pair added
  or updated. It's useful for dynamically modifying parameters in response to user
  interactions or other events.

  ## Parameters

  - `assigns` - Socket or assigns map containing the current `:pex` parameters
  - `key` - The parameter key to add or update
  - `value` - The new value for the parameter

  ## Returns

  A new parameter map with the updated value.

  ## Examples

      # In a LiveView event handler
      def handle_event("set_filter", %{"type" => filter_type}, socket) do
        new_params = put_param(socket, :filter, filter_type)
        {:noreply, push_patch(socket, to: ~p"/search?\#{new_params}")}
      end

      # Direct usage with assigns map
      assigns = %{pex: %{search: "old query", page: 1}}
      new_params = put_param(assigns, :search, "new query")
      # => %{search: "new query", page: 1}
  """
  @spec put_param(Socket.t() | map(), atom(), any()) :: Pex.pex_params()
  def put_param(assigns, key, value) do
    params = params(assigns)
    Map.put(params, key, value)
  end

  @doc """
  Removes a parameter from the current parameter map.

  This function creates a new parameter map with the specified key removed.
  Useful for clearing filters or removing unwanted parameters.

  ## Parameters

  - `assigns` - Socket or assigns map containing the current `:pex` parameters
  - `key` - The parameter key to remove

  ## Returns

  A new parameter map with the specified key removed.

  ## Examples

      # Remove a filter parameter
      def handle_event("clear_filter", _params, socket) do
        new_params = delete_param(socket.assigns, :filter)
        {:noreply, push_patch(socket, to: ~p"/search?\#{new_params}")}
      end

      # Direct usage
      assigns = %{pex: %{search: "query", filter: "active", page: 1}}
      new_params = delete_param(assigns, :filter)
      # => %{search: "query", page: 1}
  """
  @spec delete_param(Socket.t() | map(), atom()) :: Pex.pex_params()
  def delete_param(assigns, key) do
    params = params(assigns)
    Map.delete(params, key)
  end

  @doc """
  Removes multiple parameters from the current parameter map.

  This function creates a new parameter map with all specified keys removed.
  Useful for bulk removal of parameters, such as clearing all filters.

  ## Parameters

  - `assigns` - Socket or assigns map containing the current `:pex` parameters
  - `keys` - List of parameter keys to remove

  ## Returns

  A new parameter map with the specified keys removed.

  ## Examples

      # Clear all filter-related parameters
      def handle_event("clear_all_filters", _params, socket) do
        filter_keys = [:category, :price_min, :price_max, :brand]
        new_params = drop_params(socket, filter_keys)
        {:noreply, push_patch(socket, to: ~p"/search?\#{params}")}
      end

      # Direct usage
      assigns = %{pex: %{search: "query", filter: "active", sort: "name", page: 1}}
      new_params = drop_params(assigns, [:filter, :sort])
      # => %{search: "query", page: 1}
  """
  @spec drop_params(Socket.t() | map(), [atom()]) :: Pex.pex_params()
  def drop_params(assigns, keys) do
    params = params(assigns)
    Map.drop(params, keys)
  end

  @doc """
  Updates a parameter using a function, with a default value if the key doesn't exist.

  This function applies an update function to an existing parameter value, or uses
  the default value if the parameter doesn't exist. Useful for incrementing counters,
  toggling flags, or other functional updates.

  ## Parameters

  - `assigns` - Socket or assigns map containing the current `:pex` parameters
  - `key` - The parameter key to update
  - `default` - Default value to use if the key doesn't exist
  - `update_fn` - Function to apply to the current value

  ## Returns

  A new parameter map with the updated value.

  ## Examples

      # Increment a page counter
      def handle_event("next_page", _params, socket) do
        new_params = update_param(socket.assigns, :page, 1, &(&1 + 1))
        {:noreply, push_patch(socket, to: ~p"/search?\#{new_params}")}
      end

      # Direct usage
      assigns = %{pex: %{count: 5, enabled: true}}
      new_params = update_param(assigns, :count, 0, &(&1 * 2))
      # => %{count: 10, enabled: true}

      # With missing key
      assigns = %{pex: %{enabled: true}}
      new_params = update_param(assigns, :count, 0, &(&1 + 1))
      # => %{count: 1, enabled: true}
  """
  @spec update_param(Socket.t() | map(), atom(), any(), (any() -> any())) :: Pex.pex_params()
  def update_param(assigns, key, default, update_fn) do
    params = params(assigns)
    Map.update(params, key, default, update_fn)
  end
end
