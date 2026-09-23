defmodule Frontier.Record do
  @moduledoc """
  `orbit-census-v1` records (design section 3.3 and 3.4).

  Decoding is total: every binary is either a record or `{:malformed, field}`.
  Encoding is its inverse, so `encode(decode(line)) == line` for every
  accepted line. The aggregate is a commutative monoid with identity `empty/0`.
  """

  @tag "orbit-census-v1"
  # Sums are at most p (p - 1) < 2^64 (section 3.4); every other field is below 2^32.
  @bound 4_294_967_296
  @wide_bound 18_446_744_073_709_551_616
  @wide_fields [:sum_mu, :sum_lambda]
  @block_fields [:p, :c, :cap, :lo, :hi]
  @agg_fields [:n, :resolved, :sum_mu, :sum_lambda, :periodic, :has_w, :w_seed, :w_mu, :w_lambda]

  @enforce_keys [:block, :agg]
  defstruct [:block, :agg]

  @type block :: {non_neg_integer, non_neg_integer, non_neg_integer, non_neg_integer, non_neg_integer}
  @type agg :: %{atom => non_neg_integer}
  @type t :: %__MODULE__{block: block, agg: agg}

  def agg_fields, do: @agg_fields

  @spec empty() :: agg
  def empty, do: Map.new(@agg_fields, &{&1, 0})

  @spec decode(binary) :: {:ok, t} | {:malformed, String.t()}
  def decode(line) when is_binary(line) do
    with [@tag | tokens] <- String.split(line, " "),
         true <- length(tokens) == length(@block_fields ++ @agg_fields),
         {:ok, values} <- parse_all(Enum.zip(@block_fields ++ @agg_fields, tokens)) do
      {block, agg} = Enum.split(values, length(@block_fields))
      {:ok, %__MODULE__{block: List.to_tuple(block), agg: Map.new(Enum.zip(@agg_fields, agg))}}
    else
      {:malformed, _} = refusal -> refusal
      _ -> {:malformed, "arity"}
    end
  end

  defp parse_all(pairs) do
    parsed = Enum.map(pairs, fn {name, token} -> {name, canonical_integer(token, bound(name))} end)

    case Enum.find(parsed, &match?({_, :error}, &1)) do
      nil -> {:ok, Enum.map(parsed, fn {_, {:ok, n}} -> n end)}
      {name, :error} -> {:malformed, Atom.to_string(name)}
    end
  end

  defp bound(name) when name in @wide_fields, do: @wide_bound
  defp bound(_name), do: @bound

  defp canonical_integer("0", _bound), do: {:ok, 0}

  defp canonical_integer(<<first, _::binary>> = token, bound)
       when first in ?1..?9 and byte_size(token) <= 20 do
    if token =~ ~r/\A[0-9]+\z/ and String.to_integer(token) < bound,
      do: {:ok, String.to_integer(token)},
      else: :error
  end

  defp canonical_integer(_token, _bound), do: :error

  @spec encode(t) :: binary
  def encode(%__MODULE__{block: block, agg: agg}) do
    Enum.join([@tag | Tuple.to_list(block) ++ Enum.map(@agg_fields, &Map.fetch!(agg, &1))], " ")
  end

  @spec merge(agg, agg) :: agg
  def merge(a, b) do
    w = if witness_first?(a, b), do: a, else: b
    sums = Map.new([:n, :resolved, :sum_mu, :sum_lambda, :periodic], &{&1, a[&1] + b[&1]})
    Map.merge(sums, Map.take(w, [:has_w, :w_seed, :w_mu, :w_lambda]))
  end

  defp witness_first?(_a, %{has_w: 0}), do: true
  defp witness_first?(%{has_w: 0}, _b), do: false

  defp witness_first?(a, b),
    do: {-(a.w_mu + a.w_lambda), a.w_seed} <= {-(b.w_mu + b.w_lambda), b.w_seed}

  @doc "SHA-256 over the newline-terminated lines, in order (design section 3.4)."
  @spec digest([binary]) :: String.t()
  def digest(lines), do: :crypto.hash(:sha256, Enum.map(lines, &[&1, ?\n])) |> Base.encode16(case: :lower)
end
