# DateTime type benchmarks - one job per validator, plus one running them all together.
# mix run test/benchmark/types/datetime.exs

Code.require_file("../bench.exs", __DIR__)

params = %{"value" => "2026-07-04T12:00:00Z"}

%{
  "cast only" => [type: :datetime],
  "min" => [type: :datetime, validators: [min: ~U[2020-01-01 00:00:00Z]]],
  "max" => [type: :datetime, validators: [max: ~U[2030-12-31 23:59:59Z]]],
  "in" => [type: :datetime, validators: [in: [~U[2026-07-04 12:00:00Z]]]],
  "all validators" => [
    type: :datetime,
    validators: [
      min: ~U[2020-01-01 00:00:00Z],
      max: ~U[2030-12-31 23:59:59Z],
      in: [~U[2026-07-04 12:00:00Z]]
    ]
  ]
}
|> Map.new(fn {name, opts} ->
  schema = %{value: opts}
  {name, fn -> Filtr.run(schema, params) end}
end)
|> Bench.run()
