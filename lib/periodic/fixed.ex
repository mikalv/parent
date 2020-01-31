defmodule Periodic.Fixed do
  @type opt :: {:precision, pos_integer} | {:now, now_fun} | {:when, filter}

  @type now_fun :: (() -> DateTime.t())

  @type filter :: %{
          optional(:second) => filter(Calendar.second()),
          optional(:minute) => filter(Calendar.minute()),
          optional(:hour) => filter(Calendar.hour()),
          optional(:day_of_week) => filter(day_of_week),
          optional(:day) => filter(Calendar.day()),
          optional(:month) => filter(Calendar.month()),
          optional(:year) => filter(Calendar.year())
        }

  @type day_of_week ::
          :monday
          | :tuesday
          | :wednesday
          | :thursday
          | :friday
          | :saturday
          | :sunday

  @type filter(type) :: expected_value :: type | (type -> boolean)

  @spec child_spec([opt | Periodic.opt()]) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :id, __MODULE__),
      type: :supervisor,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @spec start_link([opt | Periodic.opt()]) :: GenServer.on_start()
  def start_link(opts) do
    {opts, periodic_opts} = Keyword.split(opts, ~w/when precision now/a)

    periodic_opts
    |> Keyword.merge(
      every: Keyword.get(opts, :precision, :timer.seconds(1)),
      when: condition_fun(opts),
      when_state: Keyword.get(opts, :now, fn -> DateTime.utc_now() end)
    )
    |> Periodic.Regular.start_link()
  end

  @spec set_now_fun(GenServer.on_start(), now_fun) :: :ok
  def set_now_fun(server, now_fun), do: Periodic.Regular.set_when_state(server, now_fun)

  defp condition_fun(opts) do
    filters = normalize_filter(Keyword.fetch!(opts, :when))

    fn now_fun ->
      {matches_any_filter?(now_fun.(), filters), now_fun}
    end
  end

  defp normalize_filter(filter) when is_list(filter), do: filter
  defp normalize_filter(map) when is_map(map), do: [map]

  defp matches_any_filter?(now, filters), do: Enum.any?(filters, &matches_filter?(now, &1))

  defp matches_filter?(now, filter), do: Enum.all?(filter, &matches_part?(&1, now))

  defp matches_part?({key, filter}, now), do: matches_part?(filter, value(now, key))

  defp matches_part?(fun, value) when is_function(fun), do: fun.(value)
  defp matches_part?(expected, current), do: expected == current

  defp value(now, :day_of_week), do: now |> Date.day_of_week() |> day_name()
  defp value(now, key), do: Map.fetch!(now, key)

  ~w/monday tuesday wednesday thursday friday saturday sunday/a
  |> Enum.with_index(1)
  |> Enum.each(fn {name, index} -> defp day_name(unquote(index)), do: unquote(name) end)
end
