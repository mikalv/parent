defmodule Periodic.Regular do
  use Periodic

  @type opt ::
          {:every, pos_integer}
          | {:initial_delay, non_neg_integer}
          | {:when, (() -> boolean)}

  @spec child_spec([opt | Periodic.opt()]) :: Supervisor.child_spec()
  def child_spec(opts) do
    opts
    |> super()
    |> Supervisor.child_spec(id: Keyword.get(opts, :id, __MODULE__))
  end

  @spec start_link([opt | Periodic.opt()]) :: GenServer.on_start()
  def start_link(opts) do
    {opts, periodic_opts} = Keyword.split(opts, ~w/every initial_delay when/a)
    every = Keyword.fetch!(opts, :every)
    initial_delay = Keyword.get(opts, :initial_delay, every)
    condition = Keyword.get(opts, :when)
    when_state = Keyword.get(opts, :when_state)

    Periodic.start_link(
      __MODULE__,
      {every, initial_delay, condition, when_state},
      periodic_opts
    )
  end

  @spec set_when_state(GenServer.name(), any) :: :ok
  def set_when_state(server, new_state),
    do: GenServer.call(server, {:set_when_state, new_state})

  @impl GenServer
  def init({every, initial_delay, condition, when_state}) do
    target_time = :erlang.monotonic_time(:millisecond) + initial_delay
    Periodic.enqueue_tick(initial_delay)

    {:ok,
     %{
       target_time: target_time,
       every: every,
       condition: condition,
       when_state: when_state
     }}
  end

  @impl GenServer
  def handle_call({:set_when_state, when_state}, _from, state),
    do: {:reply, :ok, %{state | when_state: when_state}}

  @impl Periodic
  def handle_tick(state) do
    {condition_met?, when_state} = condition_met?(state)
    if condition_met?, do: Periodic.start_job()
    Periodic.enqueue_tick(state.every, now: state.target_time)

    {:noreply, %{state | target_time: state.target_time + state.every, when_state: when_state}}
  end

  defp condition_met?(%{condition: nil}), do: {true, nil}

  defp condition_met?(%{condition: condition, when_state: when_state}),
    do: condition.(when_state)
end
