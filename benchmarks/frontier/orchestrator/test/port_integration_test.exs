defmodule Frontier.PortIntegrationTest do
  @moduledoc """
  The real kernels behind Ports. Requires `FRONTIER_MOJO_BIN` and
  `FRONTIER_BEND_SOURCE` (set by `pixi run test-orchestrator`) and the Bend 1
  binaries `FRONTIER_BEND1` and `FRONTIER_HVM1`.
  A missing toolchain fails; it does not skip.
  """
  use ExUnit.Case, async: true

  alias Frontier.{Census, PortKernel, Record, Vectors}

  setup_all do
    mojo = System.get_env("FRONTIER_MOJO_BIN") || flunk("FRONTIER_MOJO_BIN is not set")
    source = System.get_env("FRONTIER_BEND_SOURCE") || flunk("FRONTIER_BEND_SOURCE is not set")
    bend = System.get_env("FRONTIER_BEND1") || flunk("FRONTIER_BEND1 is not set")
    hvm = System.get_env("FRONTIER_HVM1") || flunk("FRONTIER_HVM1 is not set")
    assert Enum.all?([mojo, source, bend, hvm], &File.exists?/1)
    %{mojo: PortKernel.mojo(mojo), bend: PortKernel.bend(bend, hvm, source)}
  end

  test "Mojo answers every census vector and accepts it on replay", %{mojo: mojo} do
    for line <- Vectors.census_lines() do
      assert mojo.census.(Vectors.block_of(line)) == {:ok, line}
      assert mojo.replay.(line) == :accepted
    end
  end

  test "Mojo replay gives the reference's reason for every tampered vector", %{mojo: mojo} do
    for [reason, line] <- Vectors.cases("tampered"), do: assert(mojo.replay.(line) == {:rejected, reason})
  end

  test "Bend proposes, Mojo decides: small blocks end to end", %{mojo: mojo, bend: bend} do
    lines = Vectors.census_lines() |> Enum.filter(&(elem(Vectors.block_of(&1), 0) <= 1009))
    blocks = Enum.map(lines, &Vectors.block_of/1)
    %{ledger: ledger, digest: digest} = Census.run(blocks, bend, mojo, max_concurrency: 2)
    assert Enum.map(ledger, &elem(&1, 1)) == Enum.map(lines, &{:accepted, &1})
    assert digest == Record.digest(lines)
  end

  # About two minutes: a record with a sum of 2^32 or more costs at least 2^32
  # steps to compute, and replay computes it again.
  @tag timeout: 1_800_000
  test "a sum of 2^32 or more is accepted end to end (the first overflow report)" do
    [[line]] = Vectors.cases("wide")
    mojo = PortKernel.mojo(System.fetch_env!("FRONTIER_MOJO_BIN"), timeout: 900_000)
    %{ledger: [{_, verdict}], digest: digest} = Census.run([Vectors.block_of(line)], mojo, mojo)
    assert verdict == {:accepted, line}
    assert digest == Record.digest([line])
  end

  test "a garbled kernel is an infrastructure fault, and exhausts rather than decides", %{mojo: mojo} do
    broken = %{mojo | census: fn _ -> PortKernel.run("false", []) end}
    assert Census.drive({7, 3, 7, 0, 7}, 2, broken.domain, broken, mojo) == :exhausted
    assert PortKernel.bend_census({:ok, "Errors:\n  Unbound variable\n"}) |> elem(0) == :infra
    assert PortKernel.mojo_replay({:ok, "accepted\naccepted\n"}) |> elem(0) == :infra
  end
end
