defmodule Periodic.WithPauseTest do
  use ExUnit.Case, async: true
  import Periodic.Test
  import Periodic.TestHelper, except: [start_scheduler!: 1, start_job!: 1]

  setup do
    observe(:test_job)
  end

  test "ticks after the event has finished" do
    scheduler = start_scheduler!(delay_mode: :shifted, duration: 100)
    assert_periodic_event(:test_job, :next_tick, %{scheduler: ^scheduler, in: 100})
    refute_periodic_event(:test_job, :next_tick, %{scheduler: ^scheduler})

    tick(scheduler)
    assert_periodic_event(:test_job, :started, %{scheduler: ^scheduler, job: job})
    refute_periodic_event(:test_job, :next_tick, %{scheduler: ^scheduler})

    finish_job(job)
    assert_periodic_event(:test_job, :next_tick, %{scheduler: ^scheduler, in: 100})
  end

  defp start_scheduler!(opts),
    do: Periodic.TestHelper.start_scheduler!(Keyword.put(opts, :module, Periodic.WithPause))
end
