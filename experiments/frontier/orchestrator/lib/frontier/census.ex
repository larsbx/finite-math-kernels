defmodule Frontier.Census do
  @moduledoc """
  The imperative shell: drives each block through `Frontier.Protocol`, one
  supervised task per block, interpreting effects as calls to the challenger
  (`:propose`) and the authority (`:replay`).

  The ledger comes back in block order. The run digest exists only when
  every block is accepted: a partial run has no digest, which is fail-closed.
  """

  alias Frontier.{Contract, Protocol, Record}

  @spec run([Record.block()], Frontier.PortKernel.kernel(), Frontier.PortKernel.kernel(), keyword) ::
          %{ledger: [{Record.block(), Protocol.verdict()}], digest: String.t() | nil}
  def run(blocks, challenger, authority, opts \\ []) do
    k = Keyword.get(opts, :k, 3)
    domain = both(challenger.domain, authority.domain)

    ledger =
      Frontier.TaskSupervisor
      |> Task.Supervisor.async_stream_nolink(blocks, &drive(&1, k, domain, challenger, authority),
        ordered: true,
        timeout: :infinity,
        max_concurrency: Keyword.get(opts, :max_concurrency, System.schedulers_online())
      )
      |> Enum.zip_with(blocks, fn
        {:ok, verdict}, block -> {block, verdict}
        {:exit, _reason}, block -> {block, :exhausted}
      end)

    %{ledger: ledger, digest: digest(ledger)}
  end

  @doc "One block from start to verdict: the pure core plus effect interpretation, nothing else."
  @spec drive(Record.block(), pos_integer, function, map, map) :: Protocol.verdict()
  def drive(block, k, domain, challenger, authority) do
    {state, effects} = Protocol.new(block, k, Contract.refusal(block, domain))
    loop(state, effects, challenger, authority)
  end

  defp loop(state, [], _challenger, _authority), do: Protocol.verdict(state)

  defp loop(state, [effect], challenger, authority) do
    {state, effects} = Protocol.step(state, perform(effect, challenger, authority))
    loop(state, effects, challenger, authority)
  end

  defp perform({:propose, block}, challenger, _authority) do
    case challenger.census.(block) do
      {:ok, line} -> {:proposal, line}
      {:refused, reason} -> {:refused, reason}
      {:infra, reason} -> {:fault, reason}
    end
  end

  defp perform({:replay, line}, _challenger, authority) do
    case authority.replay.(line) do
      {:infra, reason} -> {:fault, reason}
      verdict -> {:verdict, verdict}
    end
  end

  defp both(d1, d2), do: fn block -> with :ok <- d1.(block), do: d2.(block) end

  defp digest(ledger) do
    if Enum.all?(ledger, &match?({_, {:accepted, _}}, &1)),
      do: ledger |> Enum.map(fn {_, {:accepted, line}} -> line end) |> Record.digest(),
      else: nil
  end
end
