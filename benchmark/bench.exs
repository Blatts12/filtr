defmodule Bench do
  @moduledoc """
  Thin wrapper around `Benchee.run/2` so every suite shares one configuration.
  BENCH_TIME=1 mix run test/benchmark/types/string.exs
  """

  # {env var, Benchee option, default}
  @env_opts [
    {"BENCH_WARMUP", :warmup, 0},
    {"BENCH_TIME", :time, 1},
    {"BENCH_MEMORY_TIME", :memory_time, 1},
    {"BENCH_PARALLEL", :parallel, 2}
  ]

  def run(jobs, extra \\ []) do
    {data, extra} = Keyword.pop(extra, :data)
    result = Benchee.run(jobs, Keyword.merge(opts(), extra))
    print_baseline(data)
    result
  end

  @doc """
  Prints how much memory the benchmark inputs themselves occupy, so Benchee's
  memory column can be read against the size of the data being processed.

  Pass `data:` to `run/2` as a single term or a list of `{name, term}` pairs.
  """
  def print_baseline(nil), do: :ok

  def print_baseline(entries) when is_list(entries) do
    IO.puts("\nBaseline data size (input term on the heap, before any Filtr call):\n")

    Enum.each(entries, fn {name, term} ->
      shared = bytes(:erts_debug.size(term))
      copied = bytes(:erts_debug.flat_size(term))
      IO.puts("  #{name}: #{shared} shared, #{copied} copied")
    end)
  end

  def print_baseline(term), do: print_baseline(input: term)

  # Word counts are what the runtime reports; bytes are what the memory column uses.
  defp bytes(words) do
    size = words * :erlang.system_info(:wordsize)

    if size >= 1024, do: "#{Float.round(size / 1024, 2)} KB", else: "#{size} B"
  end

  def opts do
    Enum.map(@env_opts, fn {var, key, default} ->
      case System.get_env(var) do
        nil -> {key, default}
        value -> {key, parse(value)}
      end
    end)
  end

  defp parse(value) do
    case Integer.parse(value) do
      {number, ""} -> number
      _ -> String.to_float(value)
    end
  end
end
