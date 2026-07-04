# String type benchmarks - one job per validator, plus one running them all together.
# mix run test/benchmark/types/string.exs

Code.require_file("../bench.exs", __DIR__)

params = %{"value" => "benchmark"}

%{
  "cast only" => [type: :string],
  "length" => [type: :string, validators: [length: 9]],
  "min" => [type: :string, validators: [min: 3]],
  "max" => [type: :string, validators: [max: 20]],
  "pattern" => [type: :string, validators: [pattern: ~r/mark/]],
  "starts_with" => [type: :string, validators: [starts_with: "bench"]],
  "ends_with" => [type: :string, validators: [ends_with: "mark"]],
  "contains" => [type: :string, validators: [contains: "mar"]],
  "alphanumeric" => [type: :string, validators: [alphanumeric: true]],
  "in" => [type: :string, validators: [in: ["benchmark", "test"]]],
  "all validators" => [
    type: :string,
    validators: [
      min: 3,
      max: 20,
      pattern: ~r/mark/,
      starts_with: "bench",
      ends_with: "mark",
      contains: "mar",
      alphanumeric: true,
      in: ["benchmark", "test"]
    ]
  ]
}
|> Map.new(fn {name, opts} ->
  schema = %{value: opts}
  {name, fn -> Filtr.run(schema, params) end}
end)
|> Bench.run()
