# How the number of registered plugins affects a run: 1 / 2 / 5 / 10 extra plugins,
# each contributing one custom type that the schema then uses.
# mix run test/benchmark/plugins.exs

Code.require_file("bench.exs", __DIR__)

# Ten trivial plugins, each adding its own `:custom_N` type.
for n <- 1..10 do
  defmodule Module.concat(FiltrBench.Plugins, "Plugin#{n}") do
    @moduledoc false
    use Filtr.Plugin

    @custom_type String.to_atom("custom_#{n}")

    @impl true
    def types, do: [@custom_type]

    @impl true
    def cast(value, @custom_type, _opts), do: {:ok, value}

    @impl true
    def validate(_value, @custom_type, _validator, _opts), do: :ok
  end
end

all_plugins = for n <- 1..10, do: Module.concat(FiltrBench.Plugins, "Plugin#{n}")

use_plugins = fn plugins ->
  Application.put_env(:filtr, :plugins, plugins)
  :persistent_term.erase(:filtr_type_plugin_map)
  Filtr.Helpers.type_plugin_map()
  :ok
end

jobs =
  Map.new([1, 2, 5, 10], fn count ->
    plugins = Enum.take(all_plugins, count)
    schema = Map.new(1..count, fn n -> {:"field_#{n}", [type: :"custom_#{n}"]} end)
    params = Map.new(1..count, fn n -> {"field_#{n}", "value"} end)

    job =
      {fn -> Filtr.run(schema, params) end,
       before_scenario: fn input ->
         use_plugins.(plugins)
         # Return Benchee's input untouched so the arity-0 job stays arity-0.
         input
       end}

    {"#{count} plugins", job}
  end)

Bench.run(jobs)

# Leave the global plugin config the way we found it.
Application.delete_env(:filtr, :plugins)
:persistent_term.erase(:filtr_type_plugin_map)
