# SPDX-FileCopyrightText: 2019 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetTest.Case do
  @moduledoc false

  use ExUnit.CaseTemplate
  import ExUnit.CaptureLog

  using do
    quote do
      import unquote(__MODULE__)
      alias VintageNetTest.Case
    end
  end

  @spec in_tmp(atom(), function()) :: :ok
  def in_tmp(which, function) do
    path = tmp_path(which)
    _ = File.rm_rf!(path)
    File.mkdir_p!(path)
    File.cd!(path, function)
  end

  @spec capture_log_in_tmp(atom(), function()) :: :ok
  def capture_log_in_tmp(which, function) do
    capture_log(fn -> in_tmp(which, function) end)
  end

  @spec tmp_path() :: binary()
  def tmp_path() do
    Path.expand("../../test_tmp", __DIR__)
  end

  @spec tmp_path(atom()) :: binary()
  def tmp_path(extension) do
    Path.join(tmp_path(), to_string(extension))
  end
end
