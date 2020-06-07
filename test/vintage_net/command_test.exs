defmodule VintageNet.CommandTest do
  use ExUnit.Case, async: true
  alias VintageNet.Command

  test "checking for a real exe works" do
    result = Command.verify_program([bin_test: "/bin/pwd"], :bin_test)
    assert result == :ok
  end

  test "not found exe returns an error" do
    result = Command.verify_program([bin_not_real: "/bin/notreal"], :bin_not_real)
    assert result == {:error, "Can't find /bin/notreal"}
  end
end
