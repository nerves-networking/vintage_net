defmodule VintageNet.TechnologyTest do
  use ExUnit.Case
  alias VintageNet.Technology

  test "loading good configurations" do
    assert VintageNetTest.TestTechnology ==
             Technology.module_from_config!(%{
               type: VintageNetTest.TestTechnology,
               bogus: 0
             })
  end
end
