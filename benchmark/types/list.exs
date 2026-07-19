# List type benchmarks - one job per validator, plus one running them all together.
# mix run test/benchmark/types/list.exs

Code.require_file("../bench.exs", __DIR__)

params = %{"value" => [1, 2, 3, 4, 5]}

%{
  "cast only" => %{type: :list},
  "min" => %{type: :list, validators: [min: 2]},
  "max" => %{type: :list, validators: [max: 10]},
  "length" => %{type: :list, validators: [length: 5]},
  "unique" => %{type: :list, validators: [unique: true]},
  "non_empty" => %{type: :list, validators: [non_empty: true]},
  "in" => %{type: :list, validators: [in: [1, 2, 3, 4, 5]]},
  "all validators" => %{
    type: :list,
    validators: [min: 2, max: 10, length: 5, unique: true, non_empty: true, in: [1, 2, 3, 4, 5]]
  }
}
|> Map.new(fn {name, opts} ->
  schema = %{value: opts}
  {name, fn -> Filtr.run(schema, params) end}
end)
|> Bench.run()
