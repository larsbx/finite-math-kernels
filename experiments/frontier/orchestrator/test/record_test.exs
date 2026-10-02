defmodule Frontier.RecordTest do
  use ExUnit.Case, async: true

  alias Frontier.{Contract, Gen, Record, Vectors}

  test "every census vector decodes and re-encodes to itself" do
    for line <- Vectors.census_lines() do
      assert {:ok, record} = Record.decode(line)
      assert Record.encode(record) == line
      assert Contract.malformed_field(record.block) == nil
    end
  end

  test "sums range to 2^64: the wide record and forged wide sums decode and re-encode" do
    wide = for [line] <- Vectors.cases("wide"), do: line
    forged = for [_, line] <- Vectors.cases("tampered"), do: line

    for line <- wide ++ forged do
      assert {:ok, record} = Record.decode(line)
      assert Record.encode(record) == line
    end

    assert Enum.any?(wide, &(elem(Record.decode(&1), 1).agg.sum_lambda >= 2 ** 32))
    assert Record.decode("orbit-census-v1 7 3 7 0 7 7 7 6 18446744073709551615 3 1 1 2 3") |> elem(0) == :ok
  end

  test "every malformed line is refused with the reference's field" do
    for [field, line] <- Vectors.cases("decode-malformed") do
      assert Record.decode(line) == {:malformed, field}, inspect(line)
    end
  end

  test "every malformed request is refused with the reference's field" do
    for [field, request] <- Vectors.cases("request-malformed") do
      block = request |> String.split(" ") |> Enum.map(&String.to_integer/1) |> List.to_tuple()
      assert Contract.malformed_field(block) == field
    end
  end

  test "declared domains: Mojo and Bend 2 below 2^24" do
    assert Contract.mojo_domain({16_777_213, 0, 1, 0, 0}) == :ok
    assert Contract.mojo_domain({16_777_259, 0, 1, 0, 0}) == {:unsupported, "p"}
    assert Contract.bend_domain({16_777_213, 0, 16_777_213, 0, 4}) == :ok
    assert Contract.bend_domain({16_777_259, 0, 1, 0, 0}) == {:unsupported, "p"}
    assert Contract.bend_domain({7, 0, 4_294_967_295, 0, 7}) == :ok
  end

  # A witness is a function of its seed, as in real data: the seed determines
  # its rho. The order (-(mu + lambda), seed) is total only on such witnesses.
  defp agg(state) do
    {[n, mu, lam, seed, has_w], state} = Gen.many(state, 5, &Gen.int(&1, 50))
    {rho_mu, rho_lambda} = {rem(seed * 7, 13), rem(seed * 3, 11) + 1}

    w =
      if rem(has_w, 3) == 0,
        do: %{has_w: 0, w_seed: 0, w_mu: 0, w_lambda: 0},
        else: %{has_w: 1, w_seed: seed, w_mu: rho_mu, w_lambda: rho_lambda}

    {Map.merge(%{n: n, resolved: n, sum_mu: mu, sum_lambda: lam, periodic: rem(n, 2)}, w), state}
  end

  test "the aggregate is a commutative monoid" do
    {aggs, _} = Gen.many(Gen.rng(Gen.seed()), 600, &agg/1)

    for [a, b, c] <- Enum.chunk_every(aggs, 3) do
      assert Record.merge(Record.empty(), a) == a and Record.merge(a, Record.empty()) == a
      assert Record.merge(a, b) == Record.merge(b, a)
      assert Record.merge(a, Record.merge(b, c)) == Record.merge(Record.merge(a, b), c)
    end
  end

  test "the digest hashes newline-terminated lines" do
    assert Record.digest([]) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    assert Record.digest(["a", "b"]) == Base.encode16(:crypto.hash(:sha256, "a\nb\n"), case: :lower)
    refute Record.digest(["a", "b"]) == Record.digest(["ab"])
  end
end
