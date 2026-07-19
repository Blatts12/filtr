# A single schema exercising every built-in type at once - flat fields, a nested
# map, and a list of nested schemas - run in both the fallback and strict error modes.
# mix run test/benchmark/all_types.exs

Code.require_file("bench.exs", __DIR__)

schema = %{
  name: [type: :string, validators: [min: 1, max: 100]],
  age: [type: :integer, validators: [min: 0, max: 120]],
  score: [type: :float, validators: [min: 0.0]],
  active: [type: :boolean],
  born_on: [type: :date, validators: [min: ~D[1900-01-01]]],
  last_seen: [type: :datetime],
  tags: [type: {:list, :string}, validators: [min: 1]],
  address: %{
    city: [type: :string, validators: [required: true]],
    zip: [type: :string]
  },
  items: [
    type:
      {:list,
       %{
         sku: [type: :string, validators: [required: true]],
         quantity: [type: :integer, validators: [min: 1]]
       }}
  ]
}

params = %{
  "name" => "Filtr",
  "age" => "30",
  "score" => "9.5",
  "active" => "true",
  "born_on" => "1996-04-01",
  "last_seen" => "2026-07-04T12:00:00Z",
  "tags" => ["elixir", "phoenix"],
  "address" => %{"city" => "Warsaw", "zip" => "00-001"},
  "items" => [
    %{"sku" => "A-1", "quantity" => "2"},
    %{"sku" => "B-2", "quantity" => "5"}
  ]
}

Bench.run(%{
  "fallback mode" => fn -> Filtr.run(schema, params, error_mode: :fallback) end,
  "strict mode" => fn -> Filtr.run(schema, params, error_mode: :strict) end
})
