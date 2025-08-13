defmodule Pex.LiveView do
  @moduledoc """
  Phoenix LiveView helpers for Pex query parameter parsing.

  This module provides helper functions for integrating Pex
  with Phoenix LiveViews, allowing for parameter validation
  during mount and handle_params callbacks.
  """

  alias Phoenix.LiveView.Socket

  @doc """
  Parse and validate query parameters in a LiveView.

  This function is typically used in the `mount/3` or `handle_params/3` callbacks.

  ## Examples

      defmodule MyAppWeb.UserLive.Index do
        use Phoenix.LiveView
        import Pex.LiveView

        def mount(_params, _session, socket) do
          schema = %{
            page: [type: :integer, default: 1],
            search: [type: :string, optional: true]
          }
          
          case parse_live_params(socket, schema) do
            {:ok, validated_params} ->
              socket = assign(socket, :params, validated_params)
              {:ok, socket}
            
            {:error, _errors} ->
              socket = put_flash(socket, :error, "Invalid parameters")
              {:ok, socket}
          end
        end

        def handle_params(params, _uri, socket) do
          schema = %{filter: [type: :string, optional: true]}
          
          case parse_params(params, schema) do
            {:ok, validated_params} ->
              socket = assign(socket, :filter_params, validated_params)
              {:noreply, socket}
            
            {:error, _errors} ->
              {:noreply, socket}
          end
        end
      end
  """
  @spec parse_live_params(Phoenix.LiveView.Socket.t(), Pex.schema()) ::
          {:ok, map()} | {:error, map()}
  def parse_live_params(%Phoenix.LiveView.Socket{} = socket, schema) do
    # Extract params from socket's router data or connected_params
    params = get_socket_params(socket)
    Pex.parse(params, schema)
  end

  @doc """
  Parse parameters directly from a params map.

  Useful in `handle_params/3` callbacks where you have direct access to the params.

  ## Examples

      def handle_params(params, _uri, socket) do
        schema = %{tab: [type: :string, default: "overview"]}
        
        case parse_params(params, schema) do
          {:ok, validated_params} ->
            {:noreply, assign(socket, :validated_params, validated_params)}
          
          {:error, errors} ->
            {:noreply, put_flash(socket, :error, "Invalid parameters")}
        end
      end
  """
  @spec parse_params(map(), Pex.schema()) :: {:ok, map()} | {:error, map()}
  def parse_params(params, schema) when is_map(params) do
    Pex.parse(params, schema)
  end

  @doc """
  Parse and assign validated parameters to the socket.

  Automatically assigns successful results to the socket under the specified key.

  ## Examples

      def mount(_params, _session, socket) do
        schema = %{page: [type: :integer, default: 1]}
        
        case assign_parsed_params(socket, schema, :page_params) do
          {:ok, socket} ->
            # socket.assigns.page_params now contains validated parameters
            {:ok, socket}
          
          {:error, socket, errors} ->
            socket = put_flash(socket, :error, "Invalid parameters")
            {:ok, socket}
        end
      end
  """
  @spec assign_parsed_params(Phoenix.LiveView.Socket.t(), Pex.schema(), atom()) ::
          {:ok, Phoenix.LiveView.Socket.t()} | {:error, Phoenix.LiveView.Socket.t(), map()}
  def assign_parsed_params(%Phoenix.LiveView.Socket{} = socket, schema, assign_key \\ :pex_params) do
    case parse_live_params(socket, schema) do
      {:ok, validated_params} ->
        socket = %Socket{socket | assigns: Map.put(socket.assigns, assign_key, validated_params)}
        {:ok, socket}
      
      {:error, errors} ->
        error_key = String.to_atom("#{assign_key}_errors")
        socket = %Socket{socket | assigns: Map.put(socket.assigns, error_key, errors)}
        {:error, socket, errors}
    end
  end

  @doc """
  Update URL parameters with validated values.

  Useful for updating the browser URL when parameters change.

  ## Examples

      def handle_event("update_filter", params, socket) do
        schema = %{search: [type: :string], page: [type: :integer, default: 1]}
        
        case parse_params(params, schema) do
          {:ok, validated_params} ->
            socket = push_parsed_params(socket, validated_params)
            {:noreply, socket}
          
          {:error, _errors} ->
            {:noreply, socket}
        end
      end
  """
  @spec push_parsed_params(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def push_parsed_params(%Phoenix.LiveView.Socket{} = socket, params) when is_map(params) do
    # Convert params to string keys for URL
    string_params = Enum.into(params, %{}, fn {key, value} ->
      {to_string(key), to_string(value)}
    end)
    
    Phoenix.LiveView.push_patch(socket, to: "?#{URI.encode_query(string_params)}")
  end

  # Private helper to extract params from socket
  defp get_socket_params(%Phoenix.LiveView.Socket{} = socket) do
    # Try to get params from router data first, then fall back to connected_params
    case socket do
      %{private: %{connect_params: params}} when is_map(params) -> params
      %{router: %{params: params}} when is_map(params) -> params
      _ -> %{}
    end
  end
end