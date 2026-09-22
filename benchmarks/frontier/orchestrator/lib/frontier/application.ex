defmodule Frontier.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link([{Task.Supervisor, name: Frontier.TaskSupervisor}], strategy: :one_for_one)
  end
end
