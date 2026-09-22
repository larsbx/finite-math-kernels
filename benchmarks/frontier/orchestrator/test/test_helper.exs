defmodule Frontier.Vectors do
  @moduledoc "The golden vectors of `fixtures/orbit_census_v1.txt`, by kind."

  @path Path.expand("../../../../fixtures/orbit_census_v1.txt", __DIR__)

  def cases(kind) do
    @path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.reject(&String.starts_with?(&1, "#"))
    |> Enum.map(&String.split(&1, "\t"))
    |> Enum.filter(&(hd(&1) == kind))
    |> Enum.map(&tl/1)
  end

  def census_lines, do: Enum.map(cases("census"), &hd/1)
  def block_of(line), do: elem(Frontier.Record.decode(line), 1).block
end

defmodule Frontier.Gen do
  @moduledoc """
  Seeded generators: every property prints its seed, and `FRONTIER_SEED=<n>`
  replays a failing run exactly.
  """

  def seed, do: String.to_integer(System.get_env("FRONTIER_SEED") || "20260922")
  def rng(seed), do: :rand.seed_s(:exsss, {seed, seed * 7 + 1, seed * 13 + 3})
  def int(state, n), do: :rand.uniform_s(n, state) |> then(fn {x, s} -> {x - 1, s} end)

  def pick(state, list) do
    {i, state} = int(state, length(list))
    {Enum.at(list, i), state}
  end

  def many(state, count, fun) do
    Enum.map_reduce(1..count//1, state, fn _, s -> fun.(s) end)
  end
end

ExUnit.start()
