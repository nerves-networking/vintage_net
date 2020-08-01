defmodule VintageNet.CommandTest do
  use ExUnit.Case, async: true
  alias VintageNet.Command

  test "checking for a real exe works" do
    result = Command.verify_program("ip")
    assert result == :ok
  end

  test "not found exe returns an error" do
    result = Command.verify_program("notreal")
    assert result == {:error, "Can't find notreal"}
  end
end
