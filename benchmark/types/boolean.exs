# Boolean type benchmarks.
# mix run test/benchmark/types/boolean.exs

Code.require_file("../bench.exs", __DIR__)

params = %{"value" => "true"}

%{
  "cast only" => [type: :boolean],
  "in" => [type: :boolean, validators: [in: [true, false]]]
}
|> Map.new(fn {name, opts} ->
  schema = %{value: opts}
  {name, fn -> Filtr.run(schema, params) end}
end)
|> Bench.run()
