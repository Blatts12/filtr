# Cost of building the type->plugin map as the number of registered plugins grows
# (1 / 2 / 5 / 10). This is the one place plugin count genuinely matters: it runs
# once at boot and again whenever the plugin config changes, and - unlike a run -
# it is NOT amortised by the :persistent_term cache.
#
# Measures Filtr.Helpers.build_type_plugin_map/0 directly (the pure reduction over
# the plugin list), without the :persistent_term.put a full reload would do - that
# put is roughly constant in plugin count and would otherwise flatten the trend.
# mix run benchmark/plugin_registration.exs

Code.require_file("bench.exs", __DIR__)
Code.require_file("plugin_support.exs", __DIR__)

jobs =
  Map.new([1, 2, 5, 10], fn count ->
    plugins = FiltrBench.PluginSupport.take(count)

    job =
      {fn -> Filtr.Helpers.build_type_plugin_map() end,
       before_scenario: fn input ->
         # build_type_plugin_map/0 reads the registered plugins from app config.
         FiltrBench.PluginSupport.configure(plugins)
         input
       end}

    {"#{count} plugins", job}
  end)

Bench.run(jobs)

# Leave the global plugin config the way we found it.
FiltrBench.PluginSupport.reset()
