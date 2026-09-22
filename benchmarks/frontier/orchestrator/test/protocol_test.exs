defmodule Frontier.ProtocolTest do
  @moduledoc """
  The invariants of design section 6, checked on the pure projection under
  adversarial event sequences. `benchmarks/frontier/FrontierCensus.tla` checks
  the same invariants on the global specification.
  """
  use ExUnit.Case, async: true

  alias Frontier.{Gen, Protocol, Vectors}

  @line "orbit-census-v1 7 3 7 0 7 7 7 6 21 3 1 1 2 3"
  @block {7, 3, 7, 0, 7}
  @events [
    {:proposal, @line},
    {:proposal, "orbit-census-v1 7 3 6 0 7 7 7 6 21 3 1 1 2 3"},
    {:proposal, "garbage"},
    {:refused, "malformed:p"},
    {:refused, "unsupported:p"},
    {:fault, :crash},
    {:verdict, :accepted},
    {:verdict, {:rejected, "mismatch:n"}}
  ]

  # One adversarial run: returns [{event, state_before, state_after, effects}].
  defp run(state, k, length) do
    {events, _} = Gen.many(state, length, &Gen.pick(&1, @events))
    {s0, e0} = Protocol.new(@block, k, :ok)

    {trace, _} =
      Enum.map_reduce(events, s0, fn ev, s ->
        {s2, effects} = Protocol.step(s, ev)
        {{ev, s, s2, effects}, s2}
      end)

    {e0, trace}
  end

  defp runs do
    {cases, _} =
      Gen.many(Gen.rng(Gen.seed()), 3000, fn st ->
        {k, st} = Gen.int(st, 4)
        {len, st} = Gen.int(st, 12)
        {{k + 1, run(st, k + 1, len)}, elem(Gen.int(st, 1_000_000), 1)}
      end)

    cases
  end

  test "NoAcceptWithoutReplay: acceptance names a line that was sent for replay and echoes the block" do
    for {_k, {e0, trace}} <- runs(), {_ev, _, s2, _} <- trace, match?({:accepted, _}, Protocol.verdict(s2)) do
      {:accepted, line} = Protocol.verdict(s2)
      assert {:replay, line} in (e0 ++ Enum.flat_map(trace, &elem(&1, 3)))
      assert Vectors.block_of(line) == @block
    end
  end

  test "WriteOnce: a verdict never changes and a done block emits nothing" do
    for {_k, {_e0, trace}} <- runs(), {_ev, s, s2, effects} <- trace, Protocol.verdict(s) != nil do
      assert s2 == s and effects == []
    end
  end

  test "NoRetryAfterVerdict and BoundedRestarts" do
    for {k, {e0, trace}} <- runs() do
      effects = e0 ++ Enum.flat_map(trace, &elem(&1, 3))
      assert Enum.count(effects, &match?({:propose, _}, &1)) <= k
      assert Enum.all?(trace, fn {_, _, s2, _} -> s2.attempts <= k end)

      after_verdict =
        Enum.drop_while(trace, fn {ev, s, _, _} ->
          not (match?({:verdict, _}, ev) and match?({:replaying, _}, s.phase))
        end)

      assert Enum.flat_map(after_verdict, &elem(&1, 3)) |> Enum.all?(&(not match?({:propose, _}, &1)))
    end
  end

  test "no stuck state: an undecided block always has exactly one outstanding effect" do
    for {_k, {e0, trace}} <- runs() do
      assert length(e0) == 1

      for {_ev, _s, s2, effects} <- trace do
        assert (Protocol.verdict(s2) == nil and length(effects) == 1) or
                 (Protocol.verdict(s2) != nil and effects == [])
      end
    end
  end

  test "faults alone exhaust after exactly k attempts; verdicts are never retried" do
    for k <- 1..4 do
      {s, _} = Protocol.new(@block, k, :ok)
      {s, _} = Enum.reduce(1..k, {s, []}, fn _, {s, _} -> Protocol.step(s, {:fault, :crash}) end)
      assert Protocol.verdict(s) == :exhausted

      {s, _} = Protocol.new(@block, k, :ok)
      {s, [{:replay, @line}]} = Protocol.step(s, {:proposal, @line})
      {s, []} = Protocol.step(s, {:verdict, {:rejected, "mismatch:n"}})
      assert Protocol.step(s, {:fault, :crash}) == {s, []}
      assert Protocol.verdict(s) == {:rejected, "mismatch:n"}
    end
  end

  test "a refusal before dispatch is terminal and dispatches nothing" do
    assert {s, []} = Protocol.new({4099, 0, 1, 0, 0}, 3, {:unsupported, "p"})
    assert Protocol.verdict(s) == {:unsupported, "p"}
  end

  test "an answer to a different question is rejected, not replayed" do
    {s, _} = Protocol.new(@block, 3, :ok)
    assert {s, []} = Protocol.step(s, {:proposal, "orbit-census-v1 7 3 6 0 7 7 7 6 21 3 1 1 2 3"})
    assert Protocol.verdict(s) == {:rejected, "echo"}
  end
end
