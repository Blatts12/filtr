# Runtime dispatch cost as the number of REGISTERED plugins grows (1 / 2 / 5 / 10).
#
# The schema is held fixed - one field, always the same custom type - so the only
# thing that varies between jobs is how many plugins are registered, not how much
# work the schema asks for.
#
# The type->plugin map is cached in :persistent_term and looked up per field in
# O(1), so this is expected to stay flat: registering more plugins should not make
# a run slower. This benchmark exists to confirm that (see plugin_registration.exs
# for the one-time build cost that *does* scale with plugin count).
# mix run benchmark/plugins.exs

Code.require_file("bench.exs", __DIR__)
Code.require_file("plugin_support.exs", __DIR__)

# One field, always :custom_1 (handled by Plugin1, which is present in every plugin
# set). A validator is included so the plugin's validate/4 dispatch is exercised,
# not just cast/3.
schema = %{value: %{type: :custom_1, validators: [check: true]}}
params = %{"value" => "value"}

jobs =
  Map.new([1, 2, 5, 10], fn count ->
    plugins = FiltrBench.PluginSupport.take(count)

    job =
      {fn -> Filtr.run(schema, params) end,
       before_scenario: fn input ->
         FiltrBench.PluginSupport.register(plugins)
         # Return Benchee's input untouched so the arity-0 job stays arity-0.
         input
       end}

    {"#{count} plugins", job}
  end)

Bench.run(jobs)

# Leave the global plugin config the way we found it.
FiltrBench.PluginSupport.reset()
