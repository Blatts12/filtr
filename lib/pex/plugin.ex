defmodule Pex.Plugin do
  @moduledoc false

  alias Pex.Helpers

  @type cast_result :: {:ok, any()} | {:error, binary() | [binary()]}
  @type validate_result :: :ok | :error | boolean() | {:ok, any()} | {:error, binary() | [binary()]}
  @type validator :: {atom(), term()}

  @callback types() :: [atom()]
  @callback cast(type :: atom(), value :: any(), opts :: keyword()) :: cast_result()
  @callback validate(type :: atom(), value :: any(), validator :: validator(), opts :: keyword()) :: validate_result()

  @optional_callbacks [cast: 3, validate: 4]

  defmacro __using__(_opts) do
    quote do
      @behaviour Pex.Plugin

      @impl Pex.Plugin
      def types, do: []

      defoverridable types: 0
    end
  end

  @spec all() :: [module()]
  def all, do: Helpers.plugins()

  @spec find_for_type(atom()) :: module() | nil
  def find_for_type(type), do: Helpers.type_plugin_map()[type]
end
