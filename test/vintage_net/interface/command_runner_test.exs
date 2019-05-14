defmodule VintageNet.Interface.CommandRunnerTest do
  use VintageNetTest.Case
  alias VintageNet.Interface.CommandRunner

  test "creates and deletes files", context do
    in_tmp(context.test, fn ->
      file_list = [{"testing", "Hello, world"}]
      :ok = CommandRunner.create_files(file_list)

      assert File.exists?("testing")
      assert File.read!("testing") == "Hello, world"

      :ok = CommandRunner.remove_files(file_list)
      refute File.exists?("testing")
    end)
  end

  test "creates subdirectories if needed", context do
    in_tmp(context.test, fn ->
      file_list = [{"one/two/three/testing", "Hello, world"}]
      :ok = CommandRunner.create_files(file_list)

      assert File.exists?("one/two/three/testing")
      assert File.read!("one/two/three/testing") == "Hello, world"

      :ok = CommandRunner.remove_files(file_list)
      refute File.exists?("one/two/three/testing")
    end)
  end

  test "runs commands", context do
    in_tmp(context.test, fn ->
      :ok = CommandRunner.run([{:run, "touch", ["testing"]}, {:run, "touch", ["testing2"]}])

      assert File.exists?("testing")
      assert File.exists?("testing2")
    end)
  end

  test "failed command stops list", context do
    in_tmp(context.test, fn ->
      {:error, _reason} = CommandRunner.run([{:run, "false", []}, {:run, "touch", ["testing"]}])

      refute File.exists?("testing")
    end)
  end

  test "can ignore failed commands", context do
    in_tmp(context.test, fn ->
      :ok = CommandRunner.run([{:run_ignore_errors, "false", []}, {:run, "touch", ["testing"]}])

      assert File.exists?("testing")
    end)
  end

  test "can run functions", context do
    :ok =
      CommandRunner.run([
        {:fun,
         fn ->
           send(self(), :hello)
           :ok
         end}
      ])

    assert_received :hello
  end
end
