defmodule VintageNetTest.Case do
  use ExUnit.CaseTemplate

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

  def tmp_path do
    Path.expand("../../test/tmp", __DIR__)
  end

  def tmp_path(extension) do
    Path.join(tmp_path(), to_string(extension))
  end
end
