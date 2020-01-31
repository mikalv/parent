defmodule Periodic.Fixed do
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :id, __MODULE__),
      type: :supervisor,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def start_link(opts) do
    {opts, periodic_opts} = Keyword.split(opts, ~w/when precision now/a)

    periodic_opts
    |> Keyword.merge(
      every: Keyword.get(opts, :precision, :timer.seconds(1)),
      when: condition_fun(opts)
    )
    |> Periodic.Regular.start_link()
  end

  defp condition_fun(opts) do
    now_fun = Keyword.get(opts, :now, fn -> DateTime.utc_now() end)
    filters = normalize_filter(Keyword.fetch!(opts, :when))

    fn -> matches_any_filter?(now_fun.(), filters) end
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
