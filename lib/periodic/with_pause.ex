defmodule Periodic.WithPause do
  use Periodic

  @type opt :: {:duration, pos_integer} | {:initial_delay, non_neg_integer}

  @spec child_spec([opt | Periodic.opt()]) :: Supervisor.child_spec()
  def child_spec(opts) do
    opts
    |> super()
    |> Supervisor.child_spec(id: Keyword.get(opts, :id, __MODULE__))
  end

  @spec start_link([opt | Periodic.opt()]) :: GenServer.on_start()
  def start_link(opts) do
    {opts, periodic_opts} = Keyword.split(opts, ~w/duration initial_delay/a)
    duration = Keyword.fetch!(opts, :duration)
    initial_delay = Keyword.get(opts, :initial_delay, duration)
    Periodic.start_link(__MODULE__, {duration, initial_delay}, periodic_opts)
  end

  @impl GenServer
  def init({duration, initial_delay}) do
    Periodic.enqueue_tick(initial_delay)
    {:ok, duration}
  end

  @impl Periodic
  def handle_tick(duration) do
    Periodic.start_job()
    {:noreply, duration}
  end

  @impl Periodic
  def handle_job_terminated(_pid, _reason, duration) do
    Periodic.enqueue_tick(duration)
    {:noreply, duration}
  end
end
