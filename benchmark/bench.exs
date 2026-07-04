defmodule Bench do
  @moduledoc """
  Thin wrapper around `Benchee.run/2` so every suite shares one configuration.
  BENCH_TIME=1 mix run test/benchmark/types/string.exs
  """

  # {env var, Benchee option, default}
  @env_opts [
    {"BENCH_WARMUP", :warmup, 2},
    {"BENCH_TIME", :time, 10},
    {"BENCH_MEMORY_TIME", :memory_time, 10},
    {"BENCH_PARALLEL", :parallel, 2}
  ]

  def run(jobs, extra \\ []) do
    Benchee.run(jobs, Keyword.merge(opts(), extra))
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
