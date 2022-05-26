defmodule VintageNet.PowerManager.StateMachine do
  @moduledoc false

  # Power management state machine implementation
  #
  # This is a side effect free implementation of the power management state machine
  # to make it easier to test. VintageNet.PowerManager.PMControl does what this module
  # tells it to do.
  #
  # See assets/power_manager_state_machine.png for the picture.
  #
  # If you're reading this and have seen someone nicely embed a graphviz
  # state machine in hex docs, please let me know!

  @type state() ::
          :on_hold
          | :on
          | :waiting_to_power_off
          | :powering_off
          | :resetting
          | :waiting_to_power_on
          | :off_hold
          | :off

  @type action() ::
          :start_powering_off
          | :power_off
          | :power_on
          | :start_transient_timer
          | :start_watchdog_timer

  @type actions() :: [action()]

  @spec init() :: :off
  def init() do
    :off
  end

  @spec power_on(state()) :: {state(), actions()}
  def power_on(state) do
    handle(state, :power_on)
  end

  @spec power_off(state()) :: {state(), actions()}
  def power_off(state) do
    handle(state, :power_off)
  end

  @spec timeout(state()) :: {state(), actions()}
  def timeout(state) do
    handle(state, :timeout)
  end

  @spec pet_watchdog(state()) :: {state(), actions()}
  def pet_watchdog(state) do
    handle(state, :pet_watchdog)
  end

  @spec force_reset(state()) :: {state(), actions()}
  def force_reset(state) do
    handle(state, :force_reset)
  end

  @doc """
  Return information about the current state
  """
  @spec info(state(), non_neg_integer()) :: String.t()
  def info(:on_hold, time_left), do: "Starting up/on (#{time_left} ms left)"
  def info(:waiting_to_power_off, time_left), do: "Waiting to power off (#{time_left} ms left)"
  def info(:on, time_left), do: "On (watchdog timeout in #{time_left} ms)"
  def info(:resetting, time_left), do: "Resetting in #{time_left} ms"
  def info(:powering_off, time_left), do: "Power off done in #{time_left} ms"
  def info(:waiting_to_power_on, time_left), do: "Will power on in #{time_left} ms"
  def info(:off_hold, time_left), do: "Off (OK to power on in #{time_left} ms)"
  def info(:off, _time_left), do: "Off"

  # on_hold
  defp handle(:on_hold, :timeout) do
    {:on, [:start_watchdog_timer]}
  end

  defp handle(:on_hold, :power_off) do
    {:waiting_to_power_off, []}
  end

  defp handle(:on_hold, :force_reset) do
    {:resetting, [:start_powering_off]}
  end

  # waiting_to_power_off
  defp handle(:waiting_to_power_off, :timeout) do
    {:powering_off, [:start_powering_off]}
  end

  defp handle(:waiting_to_power_off, :power_on) do
    {:on_hold, []}
  end

  # on
  defp handle(:on, :timeout) do
    {:resetting, [:start_powering_off]}
  end

  defp handle(:on, :power_off) do
    {:waiting_to_power_off, [:start_transient_timer]}
  end

  defp handle(:on, :pet_watchdog) do
    {:on, [:start_watchdog_timer]}
  end

  defp handle(:on, :force_reset) do
    {:resetting, [:start_powering_off]}
  end

  # resetting
  defp handle(:resetting, :timeout) do
    {:waiting_to_power_on, [:power_off]}
  end

  defp handle(:resetting, :power_off) do
    {:powering_off, []}
  end

  # powering_off
  defp handle(:powering_off, :power_on) do
    {:resetting, []}
  end

  defp handle(:powering_off, :timeout) do
    {:off_hold, [:power_off]}
  end

  # waiting_to_power_on
  defp handle(:waiting_to_power_on, :timeout) do
    {:on_hold, [:power_on]}
  end

  defp handle(:waiting_to_power_on, :power_off) do
    {:off_hold, []}
  end

  # off_hold
  defp handle(:off_hold, :timeout) do
    {:off, []}
  end

  defp handle(:off_hold, :power_on) do
    {:waiting_to_power_on, []}
  end

  # off
  defp handle(:off, :power_on) do
    {:on_hold, [:power_on]}
  end

  # Anything that wasn't handled is a no-op
  defp handle(state, _event) do
    {state, []}
  end
end
