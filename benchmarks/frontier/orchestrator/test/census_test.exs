defmodule Frontier.CensusTest do
  @moduledoc "The shell with in-process fake kernels: supervision, ordering, fail-closed digest."
  use ExUnit.Case, async: true

  alias Frontier.{Census, Contract, Record, Vectors}

  @lines Vectors.census_lines() |> Enum.filter(&(Contract.bend_domain(Vectors.block_of(&1)) == :ok))
  @by_block Map.new(@lines, &{Vectors.block_of(&1), &1})
  @first Vectors.block_of(hd(@lines))

  defp honest(overrides \\ %{}) do
    Map.merge(
      %{
        name: :fake,
        domain: &Contract.bend_domain/1,
        census: &{:ok, Map.fetch!(@by_block, &1)},
        replay: fn line -> if line in @lines, do: :accepted, else: {:rejected, "mismatch:n"} end
      },
      overrides
    )
  end

  defp forge(line) do
    {:ok, r} = Record.decode(line)
    Record.encode(%{r | agg: %{r.agg | n: r.agg.n + 1}})
  end

  defp flaky(failures) do
    counter = :counters.new(1, [])

    honest(%{
      census: fn block ->
        :counters.add(counter, 1, 1)

        if :counters.get(counter, 1) <= failures,
          do: {:infra, :crash},
          else: {:ok, Map.fetch!(@by_block, block)}
      end
    })
  end

  test "honest challenger: every block accepted, in order, with the digest of the vector lines" do
    blocks = Map.keys(@by_block) |> Enum.shuffle()
    %{ledger: ledger, digest: digest} = Census.run(blocks, honest(), honest())
    assert Enum.map(ledger, &elem(&1, 0)) == blocks
    assert Enum.all?(ledger, fn {b, v} -> v == {:accepted, @by_block[b]} end)
    assert digest == Record.digest(Enum.map(blocks, &@by_block[&1]))
  end

  test "a lying challenger is rejected and the run has no digest" do
    liar = honest(%{census: &{:ok, forge(Map.fetch!(@by_block, &1))}})
    %{ledger: ledger, digest: nil} = Census.run(Map.keys(@by_block), liar, honest())
    assert Enum.all?(ledger, &(elem(&1, 1) == {:rejected, "mismatch:n"}))
  end

  test "infrastructure faults are retried up to k and then exhausted, never accepted" do
    assert Census.drive(@first, 3, &Contract.bend_domain/1, flaky(2), honest()) ==
             {:accepted, @by_block[@first]}

    assert Census.drive(@first, 3, &Contract.bend_domain/1, flaky(3), honest()) == :exhausted
  end

  @tag :capture_log
  test "a challenger that raises is contained by the task supervisor" do
    crasher = honest(%{census: fn _ -> raise "segfault stand-in" end})
    %{ledger: [{_, :exhausted}], digest: nil} = Census.run([@first], crasher, honest())
  end

  test "out-of-domain and malformed blocks never reach the challenger" do
    narrow = fn {p, _, _, _, _} -> if p < 100, do: :ok, else: {:unsupported, "p"} end
    tripwire = honest(%{domain: narrow, census: fn b -> flunk("dispatched #{inspect(b)}") end})
    %{ledger: ledger} = Census.run([{101, 0, 1, 0, 0}, {7, 7, 7, 0, 7}], tripwire, honest())
    assert Enum.map(ledger, &elem(&1, 1)) == [{:unsupported, "p"}, {:malformed, "c"}]
  end
end
