defmodule Periodic.RegularTest do
  use ExUnit.Case, async: true
  import Periodic.Test
  import Periodic.TestHelper, except: [start_scheduler!: 1, start_job!: 1]

  setup do
    observe(:test_job)
  end

  test "ticks in regular intervals" do
    scheduler = start_scheduler!(delay_mode: :regular, every: 100)
    assert_periodic_event(:test_job, :next_tick, %{scheduler: ^scheduler, in: 100})

    tick(scheduler)
    assert_periodic_event(:test_job, :next_tick, %{scheduler: ^scheduler, in: 100})

    tick(scheduler)
    assert_periodic_event(:test_job, :next_tick, %{scheduler: ^scheduler, in: 100})
  end

  test "on_overlap ignore" do
    {scheduler, job} = start_job!(on_overlap: :ignore)

    tick(scheduler)
    assert_periodic_event(:test_job, :skipped, %{scheduler: ^scheduler, still_running: ^job})
    refute_periodic_event(:test_job, :started, %{scheduler: ^scheduler})

    finish_job(job)
    tick(scheduler)
    assert_periodic_event(:test_job, :started, %{scheduler: ^scheduler, job: job})
  end

  test "on_overlap stop_previous" do
    {scheduler, job} = start_job!(on_overlap: :stop_previous)

    mref = Process.monitor(job)

    tick(scheduler)
    assert_receive({:DOWN, ^mref, :process, ^job, :killed})
    assert_periodic_event(:test_job, :stopped_previous, %{scheduler: ^scheduler, pid: ^job})
    assert_periodic_event(:test_job, :started, %{scheduler: ^scheduler})
  end

  test "executes the job only if the condition is met" do
    scheduler = start_scheduler!(when: &{&1, &1})

    Periodic.Regular.set_when_state(scheduler, false)
    tick(scheduler)
    refute_periodic_event(:test_job, :started, %{scheduler: ^scheduler})

    Periodic.Regular.set_when_state(scheduler, true)
    tick(scheduler)
    assert_periodic_event(:test_job, :started, %{scheduler: ^scheduler})
  end

  defp start_scheduler!(opts),
    do: Periodic.TestHelper.start_scheduler!(Keyword.put(opts, :module, Periodic.Regular))

  defp start_job!(opts),
    do: Periodic.TestHelper.start_job!(Keyword.put(opts, :module, Periodic.Regular))
end
