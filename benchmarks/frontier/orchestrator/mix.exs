defmodule Frontier.MixProject do
  use Mix.Project

  def project do
    [app: :frontier, version: "0.1.0", elixir: "~> 1.18", deps: [], start_permanent: Mix.env() == :prod]
  end

  def application do
    [extra_applications: [:crypto, :logger], mod: {Frontier.Application, []}]
  end
end
