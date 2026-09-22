defmodule Frontier.Contract do
  @moduledoc """
  Well-formedness of a block (design section 3.1) and the declared domains of
  section 3.6. The orchestrator refuses before dispatch, so no request outside
  a domain reaches a kernel. That matters most for Bend, whose u24 numbers
  wrap silently.
  """

  @bound 4_294_967_296

  @spec malformed_field(Frontier.Record.block()) :: String.t() | nil
  def malformed_field({p, c, cap, lo, hi}) do
    cond do
      not (p < @bound and prime?(p)) -> "p"
      c not in 0..(p - 1)//1 -> "c"
      cap not in 0..(@bound - 1) -> "cap"
      not (lo >= 0 and lo <= hi) -> "lo"
      not (hi <= p) -> "hi"
      true -> nil
    end
  end

  @doc "`:ok`, or the verdict that stops the block before dispatch."
  @spec refusal(Frontier.Record.block(), (Frontier.Record.block() -> :ok | {:unsupported, String.t()})) ::
          :ok | {:malformed, String.t()} | {:unsupported, String.t()}
  def refusal(block, domain) do
    case malformed_field(block) do
      nil -> domain.(block)
      field -> {:malformed, field}
    end
  end

  @doc "Mojo kernel: a visited table of `p` words (section 3.6)."
  def mojo_domain({p, _, _, _, _}) when p < 16_777_216, do: :ok
  def mojo_domain(_), do: {:unsupported, "p"}

  @doc "Bend challenger: u24 arithmetic, so `(p - 1)^2 < 2^24` and `cap < 2^24`."
  def bend_domain({p, _, cap, _, _}) do
    cond do
      p > 4093 -> {:unsupported, "p"}
      cap >= 16_777_216 -> {:unsupported, "cap"}
      true -> :ok
    end
  end

  @spec prime?(integer) :: boolean
  def prime?(p) when p < 2, do: false

  def prime?(p),
    do: Stream.iterate(2, &(&1 + 1)) |> Stream.take_while(&(&1 * &1 <= p)) |> Enum.all?(&(rem(p, &1) != 0))
end
