# SPDX-FileCopyrightText: 2021 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.ApplicationTest do
  use ExUnit.Case
  doctest VintageNet.Application

  import ExUnit.CaptureLog

  @test_config [{"bogus1", %{type: VintageNetTest.TestTechnology, bogus: 1}}]
  @test_config2 [{"bogus2", %{type: VintageNetTest.TestTechnology, bogus: 2}}]

  setup do
    # Clean up after each test
    on_exit(fn ->
      Application.put_env(:vintage_net, :config, [])
      Application.put_env(:vintage_net, :default_config, nil)
    end)

    :ok
  end

  test "configs are read from the config key" do
    Application.put_env(:vintage_net, :config, @test_config)
    assert VintageNet.Application.get_config_env() == @test_config
  end

  test "configs are read from the default_config key" do
    Application.put_env(:vintage_net, :default_config, @test_config)
    assert VintageNet.Application.get_config_env() == @test_config
  end

  test "the default_config key is preferred" do
    Application.put_env(:vintage_net, :config, @test_config)
    Application.put_env(:vintage_net, :default_config, @test_config2)
    assert VintageNet.Application.get_config_env() == @test_config2
  end

  # test common config mistakes
  test "drops configs with atom ifnames" do
    Application.put_env(
      :vintage_net,
      :default_config,
      @test_config2 ++ [{:wlan0, %{type: :atom_bad}}]
    )

    log =
      capture_log(fn ->
        assert VintageNet.Application.get_config_env() == @test_config2
      end)

    assert log =~ "Dropping invalid configuration"
  end

  test "drops configs with no type" do
    Application.put_env(
      :vintage_net,
      :default_config,
      @test_config2 ++ [{"wlan0", %{}}]
    )

    log =
      capture_log(fn ->
        assert VintageNet.Application.get_config_env() == @test_config2
      end)

    assert log =~ "Dropping invalid configuration"
  end

  test "drops configs missing tuple" do
    Application.put_env(
      :vintage_net,
      :default_config,
      @test_config2 ++ ["wlan0"]
    )

    log =
      capture_log(fn ->
        assert VintageNet.Application.get_config_env() == @test_config2
      end)

    assert log =~ "Dropping invalid configuration"
  end

  test "handles forgotten configs" do
    Application.put_env(:vintage_net, :default_config, nil)
    Application.put_env(:vintage_net, :config, nil)

    assert VintageNet.Application.get_config_env() == []
  end

  test "normalization normalizes configs" do
    {ifname, if_config} = VintageNet.Application.normalize_config(hd(@test_config))

    assert ifname == "bogus1"

    assert if_config == %{
             type: VintageNetTest.TestTechnology,
             bogus: 1,
             normalize_was_called: true
           }
  end

  test "normalization gives reasons for unrecoverable configurations errors" do
    input_config = {"bogus3", %{type: VintageNetTest.BadTechnology, bogus: 3}}

    {ifname, if_config} = VintageNet.Application.normalize_config(input_config)

    assert ifname == "bogus3"
    assert if_config.type == VintageNet.Technology.Null
    assert if_config.reason =~ "unrecoverable error"
  end
end
