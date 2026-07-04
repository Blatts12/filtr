# Float type benchmarks - one job per validator, plus one running them all together.
# mix run test/benchmark/types/float.exs

Code.require_file("../bench.exs", __DIR__)

params = %{"value" => "3.14"}

%{
  "cast only" => [type: :float],
  "min" => [type: :float, validators: [min: 0.0]],
  "max" => [type: :float, validators: [max: 10.0]],
  "positive" => [type: :float, validators: [positive: true]],
  "negative" => [type: :float, validators: [negative: true]],
  "in" => [type: :float, validators: [in: [1.5, 3.14, 9.9]]],
  "all validators" => [
    type: :float,
    validators: [min: 0.0, max: 10.0, positive: true, in: [1.5, 3.14, 9.9]]
  ]
}
|> Map.new(fn {name, opts} ->
  schema = %{value: opts}
  {name, fn -> Filtr.run(schema, params) end}
end)
|> Bench.run()
