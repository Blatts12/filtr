defmodule Filtr.Plugin do
  @moduledoc """
    Plugin behaviour
  """

  @type cast_result :: {:ok, any()} | {:error, binary() | [binary()]}
  @type validate_result ::
          :ok | :error | boolean() | {:ok, any()} | {:error, binary() | [binary()]}
  @type validator :: {atom(), term()}

  @callback types() :: [atom()]
  @callback cast(type :: atom(), value :: any(), opts :: keyword()) :: cast_result()
  @callback validate(type :: atom(), value :: any(), validator :: validator(), opts :: keyword()) ::
              validate_result()

  @optional_callbacks [cast: 3, validate: 4]

  defmacro __using__(_opts) do
    quote do
      @behaviour Filtr.Plugin

      @impl Filtr.Plugin
      def types, do: []

      defoverridable types: 0
    end
  end

  @doc """
  Returns all registered plugins including DefaultPlugin.
  """
  @spec all() :: [module()]
  def all do
    plugins = Application.get_env(:filtr, :plugins, [])
    [Filtr.DefaultPlugin | plugins]
  end

  @doc """
  Finds all plugins that support the given type.
  Returns nil if no plugins support the type.
  """
  @spec find_for_type(atom()) :: [module()] | nil
  def find_for_type(type) do
    Filtr.Helpers.type_plugin_map()[type]
  end
end
