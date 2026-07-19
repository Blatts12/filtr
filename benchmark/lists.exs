# List-of-nested-schema benchmarks at increasing nesting depth (2 / 5 / 10 / 50).
# mix run test/benchmark/lists.exs

Code.require_file("bench.exs", __DIR__)

schema = fn depth ->
  Enum.reduce(1..depth, %{value: [type: :integer, validators: [min: 0]]}, fn _, acc ->
    %{items: [type: {:list, acc}]}
  end)
end

params = fn depth ->
  Enum.reduce(1..depth, %{"value" => "1"}, fn _, acc ->
    %{"items" => [acc]}
  end)
end

[2, 5, 10, 50]
|> Map.new(fn depth ->
  schema = schema.(depth)
  params = params.(depth)
  {"depth #{depth}", fn -> Filtr.run(schema, params) end}
end)
|> Bench.run()
