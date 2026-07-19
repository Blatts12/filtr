# Filtr.collect_errors/1 benchmarks over result-map shapes: flat, deeply nested,
# lists of maps, and lists of scalars - each clean (no errors) and with errors.
# mix run benchmark/collect_errors.exs

Code.require_file("bench.exs", __DIR__)

flat = fn size, errors? ->
  Map.new(1..size, fn i ->
    value = if errors? and rem(i, 2) == 0, do: {:error, "invalid"}, else: "value"
    {:"field_#{i}", value}
  end)
end

nested = fn depth, errors? ->
  leaf = if errors?, do: {:error, "required"}, else: "value"

  Enum.reduce(1..depth, %{leaf: leaf, other: "ok"}, fn _, acc ->
    %{child: acc, sibling: "ok"}
  end)
end

list_of_maps = fn count, errors? ->
  %{
    users:
      Enum.map(1..count, fn i ->
        name = if errors? and rem(i, 10) == 0, do: {:error, "required"}, else: "user"
        %{id: i, name: name}
      end)
  }
end

list_of_scalars = fn count, errors? ->
  %{
    tags:
      Enum.map(1..count, fn i ->
        if errors? and rem(i, 10) == 0, do: {:error, "too short"}, else: "tag"
      end)
  }
end

inputs = %{
  "flat 20 clean" => flat.(20, false),
  "flat 20 with errors" => flat.(20, true),
  "nested depth 10 clean" => nested.(10, false),
  "nested depth 10 with errors" => nested.(10, true),
  "list of 100 maps clean" => list_of_maps.(100, false),
  "list of 100 maps with errors" => list_of_maps.(100, true),
  "list of 100 scalars clean" => list_of_scalars.(100, false),
  "list of 100 scalars with errors" => list_of_scalars.(100, true)
}

inputs
|> Map.new(fn {name, result} ->
  {name, fn -> Filtr.collect_errors(result) end}
end)
|> Bench.run()
