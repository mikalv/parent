defmodule Periodic.FixedTest do
  use ExUnit.Case, async: true
  import Periodic.Test

  setup do
    observe(:test_job)
  end

  test "always executes on every second when filter is empty" do
    scheduler = start_scheduler!(when: %{})

    Periodic.Fixed.set_now_fun(scheduler, &DateTime.utc_now/0)
    tick(scheduler)
    assert_periodic_event(:test_job, :started, %{scheduler: ^scheduler})
  end

  for property <- ~w/second minute hour day month year/a do
    test "correctly filters by desired #{property} value" do
      scheduler = start_scheduler!(when: %{unquote(property) => 1})

      correct = %DateTime{DateTime.utc_now() | unquote(property) => 1}
      Periodic.Fixed.set_now_fun(scheduler, fn -> correct end)
      tick(scheduler)
      assert_periodic_event(:test_job, :started, %{scheduler: ^scheduler})

      incorrect = %DateTime{DateTime.utc_now() | unquote(property) => 2}
      Periodic.Fixed.set_now_fun(scheduler, fn -> incorrect end)
      tick(scheduler)
      refute_periodic_event(:test_job, :started, %{scheduler: ^scheduler})
    end

    test "correctly filters by desired #{property} function" do
      scheduler = start_scheduler!(when: %{unquote(property) => &(&1 == 1)})

      correct = %DateTime{DateTime.utc_now() | unquote(property) => 1}
      Periodic.Fixed.set_now_fun(scheduler, fn -> correct end)
      tick(scheduler)
      assert_periodic_event(:test_job, :started, %{scheduler: ^scheduler})

      incorrect = %DateTime{DateTime.utc_now() | unquote(property) => 2}
      Periodic.Fixed.set_now_fun(scheduler, fn -> incorrect end)
      tick(scheduler)
      refute_periodic_event(:test_job, :started, %{scheduler: ^scheduler})
    end
  end

  test "correctly filters by desired day_of_week value" do
    scheduler = start_scheduler!(when: %{day_of_week: :monday})

    now = Time.utc_now()

    monday =
      Date.utc_today()
      |> Stream.iterate(&Date.add(&1, 1))
      |> Enum.find(&(Date.day_of_week(&1) == 1))

    {:ok, correct} = NaiveDateTime.new(monday, now)
    Periodic.Fixed.set_now_fun(scheduler, fn -> correct end)
    tick(scheduler)
    assert_periodic_event(:test_job, :started, %{scheduler: ^scheduler})

    {:ok, incorrect} = NaiveDateTime.new(Date.add(monday, 1), now)
    Periodic.Fixed.set_now_fun(scheduler, fn -> incorrect end)
    tick(scheduler)
    refute_periodic_event(:test_job, :started, %{scheduler: ^scheduler})
  end

  test "correctly filters combination of properties" do
    scheduler = start_scheduler!(when: %{day: 1, minute: 1})

    correct = %DateTime{DateTime.utc_now() | day: 1, minute: 1}
    Periodic.Fixed.set_now_fun(scheduler, fn -> correct end)
    tick(scheduler)
    assert_periodic_event(:test_job, :started, %{scheduler: ^scheduler})

    incorrect = %DateTime{correct | day: 2}
    Periodic.Fixed.set_now_fun(scheduler, fn -> incorrect end)
    tick(scheduler)
    refute_periodic_event(:test_job, :started, %{scheduler: ^scheduler})

    incorrect = %DateTime{correct | minute: 2}
    Periodic.Fixed.set_now_fun(scheduler, fn -> incorrect end)
    tick(scheduler)
    refute_periodic_event(:test_job, :started, %{scheduler: ^scheduler})
  end

  test "multiple properties" do
    scheduler = start_scheduler!(when: [%{day: 1}, %{minute: 1}])

    correct = %DateTime{DateTime.utc_now() | day: 1, minute: 2}
    Periodic.Fixed.set_now_fun(scheduler, fn -> correct end)
    tick(scheduler)
    assert_periodic_event(:test_job, :started, %{scheduler: ^scheduler})

    correct = %DateTime{DateTime.utc_now() | day: 2, minute: 1}
    Periodic.Fixed.set_now_fun(scheduler, fn -> correct end)
    tick(scheduler)
    assert_periodic_event(:test_job, :started, %{scheduler: ^scheduler})

    correct = %DateTime{DateTime.utc_now() | day: 1, minute: 1}
    Periodic.Fixed.set_now_fun(scheduler, fn -> correct end)
    tick(scheduler)
    assert_periodic_event(:test_job, :started, %{scheduler: ^scheduler})

    incorrect = %DateTime{correct | day: 2, minute: 2}
    Periodic.Fixed.set_now_fun(scheduler, fn -> incorrect end)
    tick(scheduler)
    refute_periodic_event(:test_job, :started, %{scheduler: ^scheduler})
  end

  defp start_scheduler!(opts),
    do: Periodic.TestHelper.start_scheduler!(Keyword.put(opts, :module, Periodic.Fixed))
end
