# SPDX-FileCopyrightText: 2025 Jonatan Männchen
#
# SPDX-License-Identifier: Apache-2.0
#
with {:module, Igniter} <- Code.ensure_loaded(Igniter) do
  defmodule VintageNet.Generator do
    @moduledoc """
    Igniter Helpers for VintageNet.
    """

    alias Igniter.Code.Common
    alias Igniter.Code.List
    alias Igniter.Code.Tuple
    alias Igniter.Project.Config

    @spec add_regulatory_domain(igniter :: Igniter.t(), regulatory_domain :: String.t()) ::
            Igniter.t()
    def add_regulatory_domain(igniter, regulatory_domain) do
      Config.configure_new(
        igniter,
        "target.exs",
        :vintage_net,
        [:regulatory_domain],
        regulatory_domain
      )
    end

    @spec configure_interface(
            igniter :: Igniter.t(),
            name :: String.t(),
            type :: module(),
            config :: Keyword.t(),
            update :: (Sourceror.Zipper.t() -> {:ok, Sourceror.Zipper.t()} | :error)
          ) :: Igniter.t()
    def configure_interface(igniter, name, type, config, update \\ &{:ok, &1}) do
      config =
        config
        |> Keyword.put(:type, type)
        |> Enum.sort_by(fn
          # Put type first
          {:type, value} -> {1, :type, value}
          {key, value} -> {2, key, value}
        end)
        |> then(&{:%{}, [], &1})

      new_entry_ast = {name, config}

      Config.configure(
        igniter,
        "target.exs",
        :vintage_net,
        [:interfaces],
        {:code, [new_entry_ast]},
        updater: fn zipper ->
          zipper
          |> move_to_interface_config(name)
          |> case do
            {:ok, zipper} -> Common.within(zipper, update)
            :error -> List.append_to_list(zipper, new_entry_ast)
          end
        end
      )
    end

    @spec move_to_interface_config(Sourceror.Zipper.t(), name :: String.t()) ::
            {:ok, Sourceror.Zipper.t()} | :error
    def move_to_interface_config(zipper, name) do
      zipper
      |> List.move_to_list_item(fn zipper ->
        with true <- Tuple.tuple?(zipper),
             {:ok, first} <- Tuple.tuple_elem(zipper, 0) do
          Common.nodes_equal?(first, name)
        else
          _ ->
            false
        end
      end)
      |> case do
        {:ok, zipper} ->
          Tuple.tuple_elem(zipper, 1)

        :error ->
          :error
      end
    end
  end
end
