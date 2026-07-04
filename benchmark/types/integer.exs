# Integer type benchmarks - one job per validator, plus one running them all together.
# mix run test/benchmark/types/integer.exs

Code.require_file("../bench.exs", __DIR__)

params = %{"value" => "42"}

%{
  "cast only" => [type: :integer],
  "min" => [type: :integer, validators: [min: 0]],
  "max" => [type: :integer, validators: [max: 100]],
  "positive" => [type: :integer, validators: [positive: true]],
  "negative" => [type: :integer, validators: [negative: true]],
  "in" => [type: :integer, validators: [in: [7, 42, 99]]],
  "all validators" => [
    type: :integer,
    validators: [min: 0, max: 100, positive: true, in: [7, 42, 99]]
  ]
}
|> Map.new(fn {name, opts} ->
  schema = %{value: opts}
  {name, fn -> Filtr.run(schema, params) end}
end)
|> Bench.run()
