defmodule Pex.Decorator do
  @moduledoc """
  Decorator for automatically parsing and validating query parameters in Phoenix controllers.

  This module provides decorators that can be applied to controller actions
  to automatically parse and validate query parameters according to a schema.
  """

  use Decorator.Define, [pex_params: 1]

  @doc """
  Decorator that parses and validates query parameters for a controller action.

  The decorator looks for a `@pex_schema` module attribute that defines the parameter schema.
  If validation succeeds, the parsed parameters are stored in `conn.assigns.pex_params`.
  If validation fails, the decorator will send a 400 Bad Request response with error details.

  ## Usage

      defmodule MyAppWeb.UserController do
        use Phoenix.Controller
        use Pex.Controller

        @pex_schema %{
          page: [type: :integer, default: 1, validator: &Pex.Validators.positive/1],
          limit: [type: :integer, default: 10, validator: &Pex.Validators.range(&1, 1, 100)]
        }

        @decorate pex_params(@pex_schema)
        def index(conn, _params) do
          # Access validated params via conn.assigns.pex_params
          render(conn, "index.html")
        end
      end

  ## Parameters

  - `schema` - The parameter validation schema

  ## Assigns

  The decorator sets the following assigns on the connection:
  - `pex_params` - Map of successfully validated parameters
  - `pex_errors` - Map of validation errors (only set on failure)
  """
  def pex_params(schema, body, context) do
    quote do
      def unquote(context.name)(var!(conn), var!(params)) do
        case Pex.parse(var!(conn).params, unquote(schema)) do
          {:ok, validated_params} ->
            var!(conn) = Plug.Conn.assign(var!(conn), :pex_params, validated_params)
            unquote(body)
          
          {:error, errors} ->
            var!(conn)
            |> Plug.Conn.assign(:pex_errors, errors)
            |> Plug.Conn.put_status(:bad_request)
            |> Phoenix.Controller.json(%{errors: format_errors(errors)})
            |> Plug.Conn.halt()
        end
      end
    end
  end

  @doc """
  Formats validation errors for JSON response.
  
  ## Examples
  
      iex> Pex.Decorator.format_errors(%{page: "must be positive", limit: "required"})
      %{"page" => "must be positive", "limit" => "required"}
  """
  @spec format_errors(map()) :: map()
  def format_errors(errors) when is_map(errors) do
    Enum.into(errors, %{}, fn {field, error} ->
      {to_string(field), error}
    end)
  end
end