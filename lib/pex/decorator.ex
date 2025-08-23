defmodule Pex.Decorator do
  @moduledoc """
  Provides decorator functionality for Phoenix controllers using the decorator package.

  This module defines the `pex` decorator that can be used to automatically parse
  and validate parameters in Phoenix controller actions. It integrates seamlessly
  with Phoenix controllers by intercepting the params before the action executes.

  ## Usage

  To use the decorator, first add it to your controller:

      defmodule MyAppWeb.UserController do
        use MyAppWeb, :controller
        use Decorator.Define, pex: 1

        @decorate pex(schema: %{
          name: [type: :string, required: true],
          age: [type: :integer, min: 18]
        })
        def create(conn, params) do
          # params is now validated and cast according to schema
          IO.inspect(params) # %{name: "John", age: 25}
          # ... rest of controller action
        end
      end

  ## Decorator Options

  - `:schema` - The parameter schema definition (required)
  - `:error_mode` - Controls error handling behavior (`:strict`, `:fallback`, `:raise`, or `function`)

  ## Error Handling

  By default, the decorator returns `{:error, errors}` if parameter validation fails.
  Use `:error_mode` option to control error handling:

      @decorate pex(schema: %{name: [type: :string, default: "Anonymous"]}, error_mode: :fallback)
      def action(conn, params) do
        # params.name will be "Anonymous" if validation fails
      end

  ## Examples

      # Basic usage
      @decorate pex(schema: %{
        q: [type: :string, required: true],
        page: [type: :integer, default: 1, min: 1]
      })
      def search(conn, params) do
        # params.q is guaranteed to be a string
        # params.page is guaranteed to be an integer >= 1
      end

      # With fallback mode
      @decorate pex(schema: %{
        filter: [type: :string, default: "all"],
        sort: [type: :string, in: ["name", "date"], default: "name"]
      }, error_mode: :fallback)
      def index(conn, params) do
        # Even with invalid input, params will have valid defaults
      end

  This decorator transforms the controller action to automatically parse and validate
  the `params` argument according to the provided schema before executing the action body.
  """

  use Decorator.Define, pex: 1

  def pex(opts, body, %{args: [_conn, params]}) do
    schema = Keyword.get(opts, :schema) || raise "schema is required"
    error_mode = Keyword.get(opts, :error_mode, :strict)

    quote do
      var!(params) = Pex.run(unquote(schema), unquote(params), error_mode: unquote(error_mode))
      unquote(body)
    end
  end
end
