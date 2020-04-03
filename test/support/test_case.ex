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

  def in_tmp(which, function) do
    path = tmp_path(which)
    _ = File.rm_rf!(path)
    File.mkdir_p!(path)
    File.cd!(path, function)
  end

  def capture_log_in_tmp(which, function) do
    capture_log(fn -> in_tmp(which, function) end)
  end

  def tmp_path() do
    Path.expand("../../test_tmp", __DIR__)
  end

  def tmp_path(extension) do
    Path.join(tmp_path(), to_string(extension))
  end
end
