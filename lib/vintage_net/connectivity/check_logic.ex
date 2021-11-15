defmodule VintageNet.Connectivity.CheckLogic do
  @moduledoc """
  Core logic for determining internet connectivity based on check results

  This module is meant to be used by `InternetChecker` and others for
  determining when to run checks and how many failures should change the
  network interface's state.

  It implements a state machine that figures out what the connectivity status
  is based on internet-connectivity check successes and fails. It also returns
  how long to wait between checks.

  ```mermaid
  stateDiagram-v2
    direction LR
    [*]-->internet : init

    state connected {
      internet-->lan : max failures
      lan-->internet : check succeeded
    }
    connected-->disconnected : ifdown
    disconnected-->lan : ifup
  ```
  """

  @min_interval 500
  @max_interval 30_000
  @max_fails_in_a_row 3

  @type state() :: %{
          connectivity: VintageNet.connection_status(),
          strikes: non_neg_integer(),
          interval: non_neg_integer() | :infinity
        }

  @doc """
  Initialize check state machine

  Pass in the assumed connection status. This is a best guess to start things out.
  """
  @spec init(VintageNet.connection_status()) :: state()
  def init(:internet) do
    # Best case, but check quickly to verify that the internet truly is reachable.
    %{connectivity: :internet, strikes: 0, interval: @min_interval}
  end

  def init(:lan) do
    %{connectivity: :lan, strikes: @max_fails_in_a_row, interval: @min_interval}
  end

  def init(other) when other in [:disconnected, nil] do
    %{connectivity: :disconnected, strikes: @max_fails_in_a_row, interval: :infinity}
  end

  @doc """
  Call this when the interface comes up

  It is assumed that the interface has LAN connectivity now and a check will
  be scheduled to happen shortly.
  """
  @spec ifup(state()) :: state()
  def ifup(%{connectivity: :disconnected} = state) do
    # Physical layer is up. Optimistically assume that the LAN is accessible and
    # start polling again after a short delay
    %{state | connectivity: :lan, interval: @min_interval}
  end

  def ifup(state), do: state

  @doc """
  Call this when the interface goes down

  The interface will be categorized as `:disconnected` until `ifup/1` gets
  called again.
  """
  @spec ifdown(state()) :: state()
  def ifdown(state) do
    # Physical layer is down. Don't poll for connectivity since it won't happen.
    %{state | connectivity: :disconnected, interval: :infinity}
  end

  @doc """
  Call this when an Internet connectivity check succeeds
  """
  @spec check_succeeded(state()) :: state()
  def check_succeeded(%{connectivity: :disconnected} = state), do: state

  def check_succeeded(state) do
    # Success - reset the number of strikes to stay in Internet mode
    # even if there are hiccups.
    %{state | connectivity: :internet, strikes: 0, interval: @max_interval}
  end

  @doc """
  Call this when an Internet connectivity check fails

  Depending on how many failures have happened it a row, the connectivity may
  be degraded to `:lan`.
  """
  @spec check_failed(state()) :: state()
  def check_failed(%{connectivity: :internet} = state) do
    # There's no discernment between types of failures. Everything means
    # that the internet is not available and every failure could be a hiccup.
    # NOTE: only `ifdown/1` can transition to the `:disconnected` state since only
    #       `ifup/1` can exit the `:disconnected` state.
    strikes = state.strikes + 1

    if strikes < @max_fails_in_a_row do
      # If a check fails, retry, but don't wait as long as when everything was working
      %{state | strikes: strikes, interval: max(@min_interval, div(@max_interval, strikes + 1))}
    else
      %{state | connectivity: :lan, strikes: @max_fails_in_a_row}
    end
  end

  def check_failed(%{connectivity: :lan} = state) do
    # Back off of checks since they're not working
    %{state | interval: min(state.interval * 2, @max_interval)}
  end

  def check_failed(state), do: state
end
