defmodule Filtr.Types do
  @moduledoc false

  @type error() :: String.t()
  @type value() :: {:ok, term()} | {:error, [error()] | error()} | term()
  @type key() :: atom()
  @type params() :: map()
  @type opts() :: keyword()
  @type plugin() :: module()
  @type error_mode() :: :fallback | :string | :raise
  @type default() :: term() | (-> term())
  @type validators() :: keyword()
  @type opaque() :: :__none__ | nil
  @type plugin_type() :: atom()
  @type key_type() :: plugin_type() | opaque() | map() | {:list, key_type()}

  @typep key_schema_map() :: %{
           type: key_type(),
           validators: validators(),
           default: default(),
           error_mode: error_mode()
         }

  @type key_schema() :: map() | key_schema_map()

  @typep schema_map() :: %{
           optional(key()) => key_schema()
         }

  @type schema() :: map() | keyword() | schema_map()

  @typep context_map() :: %{
           required(:result) => result(),
           required(:params) => params(),
           required(:valid?) => boolean(),
           required(:plugin_map) => %{plugin_type() => plugin()},
           required(:opts) => opts(),
           optional(:key) => key()
         }

  @type context() :: map() | context_map()

  @type result() :: %{
          optional(key()) => term() | {:error, term()},
          required(:_valid?) => boolean()
        }
end
