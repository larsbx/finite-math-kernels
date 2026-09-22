defmodule Frontier.PortKernel do
  @moduledoc """
  Kernels as OS processes behind Erlang Ports (design section 5).

  A crash, a timeout, a non-zero exit, or output outside the kernel's exact
  answer grammar becomes `{:infra, reason}`, which the protocol may retry. It
  never becomes a verdict. Ports rather than NIFs: a faulting NIF takes the
  whole VM down with every other block's state.
  """

  alias Frontier.Contract

  @timeout 120_000

  @type kernel :: %{
          name: atom,
          domain: (Frontier.Record.block() -> :ok | {:unsupported, String.t()}),
          census: (Frontier.Record.block() -> {:ok, binary} | {:refused, binary} | {:infra, term}),
          replay: (binary -> :accepted | {:rejected, binary} | {:infra, term})
        }

  @doc "The Mojo kernel: challenger and authority, `census_cli` from `benchmarks/frontier/census_cli.mojo`."
  @spec mojo(Path.t()) :: kernel
  def mojo(bin) do
    %{
      name: :mojo,
      domain: &Contract.mojo_domain/1,
      census: &(bin |> run(["census" | block_args(&1)]) |> mojo_census()),
      replay: &(bin |> run(["replay", &1]) |> mojo_replay())
    }
  end

  @doc """
  The Bend 1 challenger: `bend --hvm-bin HVM run-c census.bend P C CAP LO HI`.
  It proposes; it cannot replay. Both binaries are explicit paths: `bend` on
  PATH is the Bend 2 of the Lane A harness, a different language.

  Each run gets its own working directory: `bend run-c` writes its compiled
  program to a fixed `.out.hvm` in the current directory, so concurrent runs
  in one directory race and one run can print another's answer. The echo
  check in `Frontier.Protocol` rejects such an answer; the scratch directory
  prevents it.
  """
  @spec bend(Path.t(), Path.t(), Path.t()) :: kernel
  def bend(bend, hvm, source) do
    source = Path.expand(source)

    %{
      name: :bend,
      domain: &Contract.bend_domain/1,
      census: fn block ->
        in_scratch_dir(&run(bend, ["--hvm-bin", hvm, "run-c", source | block_args(block)], cd: &1))
        |> bend_census()
      end,
      replay: fn _ -> {:infra, :not_an_authority} end
    }
  end

  defp in_scratch_dir(fun) do
    dir = Path.join(System.tmp_dir!(), "frontier-bend-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    try do
      fun.(dir)
    after
      File.rm_rf!(dir)
    end
  end

  defp block_args(block), do: block |> Tuple.to_list() |> Enum.map(&Integer.to_string/1)

  @doc false
  def mojo_census({:ok, out}) do
    case one_line(out) do
      {:ok, "orbit-census-v1 " <> _ = line} -> {:ok, line}
      {:ok, "malformed:" <> _ = r} -> {:refused, r}
      {:ok, "unsupported:" <> _ = r} -> {:refused, r}
      _ -> {:infra, {:garbled, out}}
    end
  end

  def mojo_census(infra), do: infra

  @doc false
  def mojo_replay({:ok, out}) do
    case one_line(out) do
      {:ok, "accepted"} ->
        :accepted

      {:ok, "infra:" <> r} ->
        {:infra, r}

      {:ok, reason} ->
        if reason =~ ~r/\A(mismatch|witness|malformed|unsupported):[a-z_]+\z/,
          do: {:rejected, reason},
          else: {:infra, {:garbled, out}}

      :error ->
        {:infra, {:garbled, out}}
    end
  end

  def mojo_replay(infra), do: infra

  @doc false
  def bend_census({:ok, out}) do
    case String.split(out, "\n") do
      ["orbit-census-v1 " <> _ = line, "Result: " <> _, ""] -> {:ok, line}
      _ -> {:infra, {:garbled, out}}
    end
  end

  def bend_census(infra), do: infra

  defp one_line(out) do
    case String.split(out, "\n") do
      [line, ""] -> {:ok, line}
      _ -> :error
    end
  end

  @doc "Run `cmd args` (options `:cd`, `:timeout`), collecting stdout; `{:ok, stdout}` only on exit status 0."
  @spec run(Path.t(), [String.t()], keyword) :: {:ok, binary} | {:infra, term}
  def run(cmd, args, opts \\ []) do
    case System.find_executable(cmd) do
      nil ->
        {:infra, {:missing, cmd}}

      exe ->
        cd = if opts[:cd], do: [cd: opts[:cd]], else: []
        port = Port.open({:spawn_executable, exe}, [:binary, :exit_status, :use_stdio, args: args] ++ cd)
        collect(port, [], System.monotonic_time(:millisecond) + Keyword.get(opts, :timeout, @timeout))
    end
  end

  defp collect(port, acc, deadline) do
    receive do
      {^port, {:data, data}} -> collect(port, [acc | data], deadline)
      {^port, {:exit_status, 0}} -> {:ok, IO.iodata_to_binary(acc)}
      {^port, {:exit_status, n}} -> {:infra, {:exit, n}}
    after
      max(deadline - System.monotonic_time(:millisecond), 0) ->
        with {:os_pid, pid} <- Port.info(port, :os_pid),
             do: System.cmd("kill", ["-KILL", Integer.to_string(pid)], stderr_to_stdout: true)

        Port.close(port)
        {:infra, :timeout}
    end
  end
end
