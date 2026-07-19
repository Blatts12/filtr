# Nested map schema benchmarks at increasing depth (2 / 5 / 10 / 50 levels).
# mix run test/benchmark/nesting.exs

Code.require_file("bench.exs", __DIR__)

schema = fn depth ->
  Enum.reduce(1..depth, %{leaf: %{type: :string, validators: [min: 1]}}, fn _, acc ->
    %{child: %{type: acc}}
  end)
end

params = fn depth ->
  Enum.reduce(1..depth, %{"leaf" => "value"}, fn _, acc ->
    %{"child" => acc}
  end)
end

[2, 5, 10, 50]
|> Map.new(fn depth ->
  schema = schema.(depth)
  params = params.(depth)
  {"depth #{depth}", fn -> Filtr.run(schema, params) end}
end)
|> Bench.run()
