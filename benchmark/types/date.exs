# Date type benchmarks - one job per validator, plus one running them all together.
# mix run test/benchmark/types/date.exs

Code.require_file("../bench.exs", __DIR__)

params = %{"value" => "2026-07-04"}

%{
  "cast only" => [type: :date],
  "min" => [type: :date, validators: [min: ~D[2020-01-01]]],
  "max" => [type: :date, validators: [max: ~D[2030-12-31]]],
  "in" => [type: :date, validators: [in: [~D[2026-07-04], ~D[2026-07-05]]]],
  "all validators" => [
    type: :date,
    validators: [min: ~D[2020-01-01], max: ~D[2030-12-31], in: [~D[2026-07-04]]]
  ]
}
|> Map.new(fn {name, opts} ->
  schema = %{value: opts}
  {name, fn -> Filtr.run(schema, params) end}
end)
|> Bench.run()
