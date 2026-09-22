defmodule Frontier.Protocol do
  @moduledoc """
  The orchestrator's projection of the census choreography (design section 6,
  `benchmarks/frontier/FrontierCensus.tla`) as a pure transition function.

      O -> B : job(block)                  effect {:propose, block}
      B -> O : proposal(line) | fault      event  {:proposal, line} | {:refused, r} | {:fault, r}
      O -> M : replay(line)                effect {:replay, line}
      M -> O : verdict                     event  {:verdict, :accepted | {:rejected, r}} | {:fault, r}
      O      : ledger(block) := verdict    state  {:done, verdict}

  Each clause of `step/2` is one action of the specification. A verdict is a
  value: only `:fault` events (infrastructure) are retried, at most `k`
  attempts in total, and nothing changes once the state is `:done`.
  """

  alias Frontier.Record

  @enforce_keys [:block, :k]
  defstruct [:block, :k, attempts: 0, phase: :proposing, proposal: nil]

  @type verdict ::
          {:accepted, binary}
          | {:rejected, String.t()}
          | {:malformed, String.t()}
          | {:unsupported, String.t()}
          | :exhausted
  @type phase :: :proposing | {:replaying, binary} | {:done, verdict}
  @type effect :: {:propose, Record.block()} | {:replay, binary}
  @type t :: %__MODULE__{block: Record.block(), k: pos_integer, attempts: non_neg_integer, phase: phase}

  @doc "Start a block; `refusal` comes from `Frontier.Contract.refusal/2` and stops it before dispatch."
  @spec new(Record.block(), pos_integer, :ok | {:malformed | :unsupported, String.t()}) :: {t, [effect]}
  def new(block, k, :ok) when k >= 1, do: {%__MODULE__{block: block, k: k, attempts: 1}, [{:propose, block}]}
  def new(block, k, refusal) when k >= 1, do: {%__MODULE__{block: block, k: k, phase: {:done, refusal}}, []}

  @spec step(t, term) :: {t, [effect]}
  def step(%__MODULE__{phase: {:done, _}} = s, _event), do: {s, []}

  def step(%__MODULE__{phase: :proposing} = s, {:proposal, line}) do
    case Record.decode(line) do
      {:ok, %Record{block: block}} when block == s.block ->
        {%{s | phase: {:replaying, line}}, [{:replay, line}]}

      {:ok, _other_block} ->
        done(s, {:rejected, "echo"})

      {:malformed, field} ->
        done(s, {:malformed, field})
    end
  end

  def step(%__MODULE__{phase: :proposing} = s, {:refused, "malformed:" <> field}),
    do: done(s, {:malformed, field})

  def step(%__MODULE__{phase: :proposing} = s, {:refused, "unsupported:" <> field}),
    do: done(s, {:unsupported, field})

  def step(%__MODULE__{phase: {:replaying, line}} = s, {:verdict, :accepted}), do: done(s, {:accepted, line})
  def step(%__MODULE__{phase: {:replaying, _}} = s, {:verdict, {:rejected, r}}), do: done(s, {:rejected, r})

  def step(%__MODULE__{attempts: n, k: k} = s, {:fault, _}) when n >= k, do: done(s, :exhausted)
  def step(%__MODULE__{phase: :proposing} = s, {:fault, _}), do: retry(s, {:propose, s.block})
  def step(%__MODULE__{phase: {:replaying, line}} = s, {:fault, _}), do: retry(s, {:replay, line})

  # Anything else is a message the choreography does not allow here. Failing
  # closed means rejecting, never waiting: waiting could deadlock.
  def step(s, event), do: done(s, {:rejected, "protocol:" <> event_name(event)})

  @spec verdict(t) :: verdict | nil
  def verdict(%__MODULE__{phase: {:done, v}}), do: v
  def verdict(_), do: nil

  defp done(s, verdict), do: {%{s | phase: {:done, verdict}}, []}
  defp retry(s, effect), do: {%{s | attempts: s.attempts + 1}, [effect]}

  defp event_name(event) when is_tuple(event), do: event |> elem(0) |> inspect()
  defp event_name(event), do: inspect(event)
end
