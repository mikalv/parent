defmodule Periodic.Regular do
  use Periodic

  def child_spec(opts) do
    opts
    |> super()
    |> Supervisor.child_spec(id: Keyword.get(opts, :id, __MODULE__))
  end

  def start_link(opts) do
    {opts, periodic_opts} = Keyword.split(opts, ~w/every initial_delay/a)
    every = Keyword.fetch!(opts, :every)
    initial_delay = Keyword.get(opts, :initial_delay, every)
    Periodic.start_link(__MODULE__, {every, initial_delay}, periodic_opts)
  end

  @impl GenServer
  def init({every, initial_delay}) do
    target_time = :erlang.monotonic_time(:millisecond) + initial_delay
    Periodic.enqueue_tick(initial_delay)
    {:ok, %{target_time: target_time, every: every}}
  end

  @impl Periodic
  def handle_tick(state) do
    Periodic.start_job()
    Periodic.enqueue_tick(state.every, now: state.target_time)
    {:noreply, %{state | target_time: state.target_time + state.every}}
  end
end
