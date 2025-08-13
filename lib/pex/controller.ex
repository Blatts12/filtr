defmodule Pex.Controller do
  @moduledoc """
  Phoenix Controller helpers for Pex query parameter parsing.

  This module provides helper functions and macros for integrating Pex
  with Phoenix controllers.
  """

  defmacro __using__(_opts) do
    quote do
      import Pex.Controller
      import Pex.Decorator
      use Decorator.Define, [pex_params: 1]
    end
  end

  @doc """
  Manually parse and validate query parameters in a controller action.

  This function is useful when you need more control over error handling
  or want to parse parameters conditionally.

  ## Examples

      def index(conn, _params) do
        schema = %{
          page: [type: :integer, default: 1],
          search: [type: :string, optional: true]
        }
        
        case parse_params(conn, schema) do
          {:ok, validated_params} ->
            # Use validated_params
            render(conn, "index.html", params: validated_params)
          
          {:error, errors} ->
            conn
            |> put_status(:bad_request)
            |> json(%{errors: errors})
        end
      end
  """
  @spec parse_params(Plug.Conn.t(), Pex.schema()) :: {:ok, map()} | {:error, map()}
  def parse_params(%Plug.Conn{} = conn, schema) do
    Pex.parse(conn.params, schema)
  end

  @doc """
  Parse and validate query parameters, assigning them to the connection.

  Similar to `parse_params/2`, but automatically assigns successful results
  to `conn.assigns.pex_params`.

  ## Examples

      def index(conn, _params) do
        schema = %{page: [type: :integer, default: 1]}
        
        case assign_parsed_params(conn, schema) do
          {:ok, conn} ->
            # conn.assigns.pex_params now contains validated parameters
            render(conn, "index.html")
          
          {:error, conn, errors} ->
            conn
            |> put_status(:bad_request)
            |> json(%{errors: errors})
        end
      end
  """
  @spec assign_parsed_params(Plug.Conn.t(), Pex.schema()) ::
          {:ok, Plug.Conn.t()} | {:error, Plug.Conn.t(), map()}
  def assign_parsed_params(%Plug.Conn{} = conn, schema) do
    case Pex.parse(conn.params, schema) do
      {:ok, validated_params} ->
        conn = Plug.Conn.assign(conn, :pex_params, validated_params)
        {:ok, conn}
      
      {:error, errors} ->
        conn = Plug.Conn.assign(conn, :pex_errors, errors)
        {:error, conn, errors}
    end
  end

  @doc """
  Get validated parameters from connection assigns.

  Returns the validated parameters if they exist, or an empty map otherwise.

  ## Examples

      def show(conn, _params) do
        validated_params = get_parsed_params(conn)
        # Use validated_params...
      end
  """
  @spec get_parsed_params(Plug.Conn.t()) :: map()
  def get_parsed_params(%Plug.Conn{} = conn) do
    Map.get(conn.assigns, :pex_params, %{})
  end

  @doc """
  Get validation errors from connection assigns.

  Returns the validation errors if they exist, or an empty map otherwise.

  ## Examples

      def index(conn, _params) do
        errors = get_param_errors(conn)
        if errors != %{} do
          # Handle errors...
        end
      end
  """
  @spec get_param_errors(Plug.Conn.t()) :: map()
  def get_param_errors(%Plug.Conn{} = conn) do
    Map.get(conn.assigns, :pex_errors, %{})
  end
end