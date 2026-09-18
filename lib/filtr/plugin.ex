defmodule Filtr.Plugin do
  @moduledoc """
  The behaviour that teaches Filtr new types and validators.

  Filtr ships with `Filtr.DefaultPlugin` for the usual types, and that covers most params.
  A plugin is what you reach for when your app has a type of its own, like money stored as
  cents, a slug, or an ID that has to be decoded before anything else can use it.

  This guide assumes you know how schemas look, which `Filtr` covers.

  ## Writing a plugin

  A plugin is a module that declares the types it owns and implements the casting and
  validation for them. Here is one that parses money into integer cents.

      defmodule MyApp.MoneyPlugin do
        use Filtr.Plugin

        @impl Filtr.Plugin
        def types, do: [:money]

        @impl Filtr.Plugin
        def cast(value, :money, _ctx) when is_integer(value), do: {:ok, value}

        def cast(value, :money, _ctx) when is_binary(value) do
          case Float.parse(String.replace(value, ~r/[$,]/, "")) do
            {amount, _} -> {:ok, trunc(amount * 100)}
            :error -> {:error, "invalid money format"}
          end
        end

        @impl Filtr.Plugin
        def validate(value, :money, {:min, min}, _ctx) do
          if value >= min, do: :ok, else: {:error, "amount too small"}
        end
      end

  Let's break down the example above:

  - `types/0` lists the type atoms this module owns. Filtr builds a type to plugin map from
    it, so a type you forget here is a type your plugin never sees.
  - `cast/3` takes the raw value, the type atom, and the run context. Return `{:ok, value}`
    or `{:error, message}`, where the message can also be a list of messages.
  - `validate/4` takes the casted value, the type, one validator as a `{name, argument}`
    tuple, and the context. Return `:ok`, `true` or `{:ok, _}` to pass, and `:error`,
    `false` or `{:error, message}` to fail. A bare `:error` becomes the message
    "invalid value".

  Notice there are no catch-all clauses. `use Filtr.Plugin` appends them at compile time
  through `@before_compile`, and they return `:not_handled`. That is how Filtr knows the
  difference between "this value is bad" and "this plugin has no opinion", and it reports
  the second as a missing cast or validator error.

  The context passed as the last argument is Filtr's internal run state, which holds the
  current params, the accumulated result, and the run options under `:opts`. Read from it
  if you need to, but treat its shape as private, because it can change between releases.

  ## Registering a plugin

  Plugins are read from application config:

      config :filtr, plugins: [MyApp.MoneyPlugin]

  Filtr builds the type to plugin map on first use and caches it in `:persistent_term`,
  which keeps lookups fast at the cost of being a process-wide cache. Changing the config
  at runtime does not invalidate it, so a plugin added after the first run stays invisible
  until the cache is cleared.

  ## Overriding built-in types

  The map is built from `[Filtr.DefaultPlugin | configured_plugins]`, and each entry
  overwrites the one before it. The last plugin that lists a type owns it completely,
  including validators you did not implement, so an override is all or nothing.

  When you only want to change part of a type, delegate the rest back:

      defmodule MyApp.TrimmedStringPlugin do
        use Filtr.Plugin

        @impl Filtr.Plugin
        def types, do: [:string]

        @impl Filtr.Plugin
        def cast(value, :string, ctx) when is_binary(value) do
          {:ok, String.trim(value)}
        end

        @impl Filtr.Plugin
        def validate(value, :string, validator, ctx) do
          Filtr.DefaultPlugin.validate(value, :string, validator, ctx)
        end
      end

  Reach for a plugin when a type shows up across several schemas. For a one-off conversion,
  a cast function in the schema's `:type` is less code and stays next to the param it
  belongs to.
  """

  @type cast_result :: {:ok, any()} | {:error, binary() | [binary()]}
  @type validate_result ::
          :ok | :error | boolean() | {:ok, any()} | {:error, binary() | [binary()]}
  @type validator :: {atom(), term()}

  @callback types() :: [atom()]
  @callback cast(value :: any(), type :: atom(), context :: map()) :: cast_result() | :not_handled
  @callback validate(value :: any(), type :: atom(), validator :: validator(), context :: map()) ::
              validate_result() | :not_handled

  @optional_callbacks [cast: 3, validate: 4]

  defmacro __using__(_opts) do
    quote do
      @behaviour Filtr.Plugin
      @before_compile Filtr.Plugin

      @impl Filtr.Plugin
      def types, do: []

      defoverridable types: 0
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      # Catch-all clause for cast/3 - returns :not_handled if no pattern matches
      def cast(_value, _type, _opts), do: :not_handled

      # Catch-all clause for validate/4 - returns :not_handled if no pattern matches
      def validate(_value, _type, _validator, _opts), do: :not_handled
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
  Returns the plugin that owns the given type, or `nil` when no plugin claims it.
  """
  @spec find_for_type(atom()) :: module() | nil
  def find_for_type(type) do
    Filtr.Helpers.type_plugin_map()[type]
  end
end
