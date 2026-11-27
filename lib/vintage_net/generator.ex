# SPDX-FileCopyrightText: 2025 Jonatan Männchen
# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
if Code.ensure_loaded?(Igniter) do
  defmodule VintageNet.Generator do
    @moduledoc """
    Igniter helpers for VintageNet

    These functions are for use in [Igniter](https://hex.pm/packages/igniter)
    installers. `mix vintage_net.install` uses them to write VintageNet's base
    configuration and the VintageNet technology libraries (`VintageNetEthernet`,
    `VintageNetWiFi`, `VintageNetDirect`, etc.) use them to add their network
    interfaces to it.

    This module is only available when Igniter is. Installers that use it need
    to be guarded the same way:

    ```elixir
    if Code.ensure_loaded?(Igniter) do
      defmodule Mix.Tasks.MyTechnology.Install do
        use Igniter.Mix.Task

        @impl Igniter.Mix.Task
        def igniter(igniter) do
          VintageNet.Generator.add_interface(igniter, "eth0",
            type: VintageNetEthernet,
            ipv4: %{method: :dhcp}
          )
        end
      end
    end
    ```

    All of the functions are idempotent and none of them change configuration
    that's already in the project unless explicitly asked to.

    ## Where the configuration goes

    VintageNet only runs on devices, so its configuration is written to
    `config/target.exs` when the project has one. That's the case for all
    Nerves projects. When there's no `config/target.exs`, `config/config.exs`
    is used instead. See `config_file/1`.
    """

    alias Igniter.Code.Common
    alias Igniter.Code.List, as: CodeList
    alias Igniter.Code.Tuple, as: CodeTuple
    alias Igniter.Project.Config
    alias Igniter.Project.Deps
    alias Sourceror.Zipper

    @typedoc """
    A network interface configuration to write to the config file

    * a map like `%{type: VintageNetEthernet, ipv4: %{method: :dhcp}}`. Maps
      don't have a key order, so `:type` is written first and the other keys
      follow in sorted order.
    * a keyword list like `[type: VintageNetEthernet, ipv4: %{method: :dhcp}]`.
      It's written as a map with the keys in the order given.
    * `{:code, quoted}` where `quoted` is the code to write. Use this when the
      configuration isn't a literal. For example, when it reads an environment
      variable.
    """
    @type interface_config() :: map() | keyword() | {:code, Macro.t()}

    @doc """
    Return the name of the config file that VintageNet's configuration goes in

    This is `"target.exs"` when the project has a `config/target.exs` and
    `"config.exs"` when it doesn't. The name is relative to the `config`
    directory like the names that `Igniter.Project.Config` uses.
    """
    @spec config_file(Igniter.t()) :: String.t()
    def config_file(igniter) do
      if Igniter.exists?(igniter, "config/target.exs"), do: "target.exs", else: "config.exs"
    end

    @doc """
    Add VintageNet's base configuration if it's missing

    The base configuration is the list of network interface configurations
    that the VintageNet technologies add to.

    ```elixir
    config :vintage_net, config: []
    ```

    If `:config` is already set, it's left alone.

    A regulatory domain isn't part of the base configuration since it only
    applies to WiFi. It's written when the `:regulatory_domain` option is
    passed or by calling `add_regulatory_domain/3`, which is what
    `mix vintage_net_wifi.install` does.

    Options:

    * `:regulatory_domain` - a regulatory domain to write if none is
      configured. Nothing is written when this isn't specified.
    """
    @spec add_base_config(Igniter.t(), keyword()) :: Igniter.t()
    def add_base_config(igniter, opts \\ []) do
      keep_formatting_if_unchanged(igniter, fn igniter ->
        igniter
        |> Config.configure_new(config_file(igniter), :vintage_net, [:config], [])
        |> maybe_add_regulatory_domain(opts[:regulatory_domain])
      end)
    end

    defp maybe_add_regulatory_domain(igniter, nil), do: igniter

    defp maybe_add_regulatory_domain(igniter, regulatory_domain),
      do: add_regulatory_domain(igniter, regulatory_domain)

    @doc """
    Set the regulatory domain

    The regulatory domain is the ISO 3166-1 alpha-2 country code for where the
    device is used or `"00"` for the world regulatory domain. It only applies
    to WiFi, so it's up to WiFi installers to call this. The other functions
    in this module don't write a regulatory domain.

    By default, the regulatory domain is only written when it's not configured
    yet. When it's added next to other `:vintage_net` keys, it's put first like
    in the configuration that `mix nerves.new` generates:

    ```elixir
    config :vintage_net, regulatory_domain: "US", config: []
    ```

    Options:

    * `:overwrite?` - set to `true` to replace a regulatory domain that's
      already configured. Defaults to `false`.
    """
    @spec add_regulatory_domain(Igniter.t(), String.t(), keyword()) :: Igniter.t()
    def add_regulatory_domain(igniter, regulatory_domain, opts \\ [])
        when is_binary(regulatory_domain) do
      configure = if opts[:overwrite?], do: &Config.configure/5, else: &Config.configure_new/5
      file = config_file(igniter)

      new? =
        not (Igniter.exists?(igniter, "config/#{file}") and
               Config.configures_key?(igniter, file, :vintage_net, :regulatory_domain))

      keep_formatting_if_unchanged(igniter, fn igniter ->
        igniter
        |> configure.(file, :vintage_net, [:regulatory_domain], regulatory_domain)
        |> maybe_move_regulatory_domain_first(file, new?)
      end)
    end

    # Igniter adds new keys to the end of `config :vintage_net, ...`. The
    # regulatory domain conventionally goes before the interface list.
    defp maybe_move_regulatory_domain_first(igniter, _file, false), do: igniter

    defp maybe_move_regulatory_domain_first(igniter, file, true) do
      Igniter.update_elixir_file(igniter, "config/#{file}", fn zipper ->
        {:ok, Zipper.traverse(zipper, &move_regulatory_domain_first/1)}
      end)
    end

    defp move_regulatory_domain_first(
           %Zipper{node: {:config, meta, [{:__block__, _, [:vintage_net]} = app, opts]}} = zipper
         )
         when is_list(opts) do
      case Enum.split_with(opts, &regulatory_domain_pair?/1) do
        {[pair], [first | _] = rest} when hd(opts) != pair ->
          Zipper.replace(zipper, {:config, meta, [app, [move_before(pair, first) | rest]]})

        _ ->
          zipper
      end
    end

    defp move_regulatory_domain_first(zipper), do: zipper

    # Sourceror places comments by line number, so the moved pair takes the
    # line of the key that it goes before or the one above that key's comments.
    # Without this, those comments would end up above the regulatory domain.
    defp move_before({{:__block__, _, [key]}, {:__block__, value_meta, [value]}}, first) do
      line = first_line(first)

      {{:__block__, [format: :keyword, line: line], [key]},
       {:__block__, Keyword.put(value_meta, :line, line), [value]}}
    end

    defp move_before(pair, _first), do: pair

    defp first_line({{_, meta, _}, _value}) do
      case meta[:leading_comments] do
        [%{line: line} | _] -> line - 1
        _ -> meta[:line]
      end
    end

    defp regulatory_domain_pair?({{:__block__, _, [:regulatory_domain]}, _value}), do: true
    defp regulatory_domain_pair?(_other), do: false

    @doc """
    Add a network interface if it's not already configured

    This adds `{ifname, config}` to the end of the `:config` list in the
    application environment for `:vintage_net`. For example,

    ```elixir
    igniter
    |> VintageNet.Generator.add_interface("eth0", type: VintageNetEthernet, ipv4: %{method: :dhcp})
    |> VintageNet.Generator.add_interface("wlan0", %{type: VintageNetWiFi})
    ```

    results in

    ```elixir
    config :vintage_net,
      config: [
        {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}},
        {"wlan0", %{type: VintageNetWiFi}}
      ]
    ```

    See `t:interface_config/0` for the ways of specifying the configuration.

    If the project already configures `ifname`, nothing is changed no matter
    what the existing configuration is. Other interfaces are left as they are
    and keep their order. The base configuration is added if it's missing. See
    `add_base_config/2`. A regulatory domain is never added. WiFi installers
    call `add_regulatory_domain/3` for that.

    If the project sets `:config` to something that isn't a list in the source
    code (a variable or function call, for example), it's not modified and a
    warning is added that asks the user to add the interface manually.
    """
    @spec add_interface(Igniter.t(), VintageNet.ifname(), interface_config()) :: Igniter.t()
    def add_interface(igniter, ifname, config) when is_binary(ifname) do
      update_interface(igniter, ifname, entry_to_quoted(ifname, config), &{:ok, &1})
    end

    @doc """
    Add a network interface or update it if it's already configured

    This is like `add_interface/3`, but lets the caller modify an existing
    configuration for `ifname`. Most installers should use `add_interface/3`
    so that they don't change what users have set up.

    The interface's configuration is `config` with `:type` set to `type`. When
    `ifname` isn't configured, it's added. When it is, `update` is called
    with a zipper that's positioned at the existing configuration (usually a
    map). Return `{:ok, zipper}` with the updated zipper or `:error` to leave
    it as is. The default is to keep the existing configuration.
    """
    @spec configure_interface(
            Igniter.t(),
            VintageNet.ifname(),
            module(),
            keyword(),
            (Zipper.t() -> {:ok, Zipper.t()} | :error)
          ) :: Igniter.t()
    def configure_interface(igniter, ifname, type, config, update \\ &{:ok, &1})
        when is_binary(ifname) and is_atom(type) and is_list(config) and is_function(update, 1) do
      config = [type: type] ++ Keyword.delete(config, :type)

      update_interface(igniter, ifname, entry_to_quoted(ifname, config), update)
    end

    @doc """
    Restrict a dependency to the project's targets

    VintageNet and its technologies configure the network of the machine that
    they run on, so they shouldn't be started on the computer that a Nerves
    project is developed on. Nerves projects handle this by giving
    dependencies a `:targets` option that refers to a module attribute. E.g.,
    `{:nerves_pack, "~> 0.7", targets: @all_targets}`.

    If `app` is a dependency in `mix.exs` that doesn't have a `:targets`
    option and another dependency has one that refers to a module attribute,
    the first such attribute is used for `app` as well. Nothing is changed
    otherwise. In particular, this does nothing when `app` isn't listed in
    `mix.exs`, like when it's brought in by `:nerves_pack`.
    """
    @spec restrict_dep_to_targets(Igniter.t(), atom()) :: Igniter.t()
    def restrict_dep_to_targets(igniter, app) when is_atom(app) do
      with {:ok, declaration} when is_binary(declaration) <- Deps.get_dep(igniter, app),
           {:ok, dep} <- Code.string_to_quoted(declaration),
           false <- has_targets_option?(dep),
           mix_exs when is_binary(mix_exs) <- existing_content(igniter, "mix.exs"),
           {:ok, quoted} <- Code.string_to_quoted(mix_exs),
           attribute when is_atom(attribute) and not is_nil(attribute) <-
             first_targets_attribute(quoted) do
        Deps.set_dep_option(igniter, app, :targets, {:@, [], [{attribute, [], nil}]})
      else
        _ -> igniter
      end
    end

    defp has_targets_option?(quoted) do
      {_quoted, found?} =
        Macro.prewalk(quoted, false, fn
          {:targets, _value} = node, _found? -> {node, true}
          node, found? -> {node, found?}
        end)

      found?
    end

    # The name of the module attribute in the first `targets: @attribute`. If
    # no dependency has one, `@all_targets` is used when mix.exs defines it.
    # That's the attribute that Nerves projects list their targets in.
    defp first_targets_attribute(quoted) do
      {_quoted, {used, all_targets?}} =
        Macro.prewalk(quoted, {nil, false}, fn
          {:targets, {:@, _, [{name, _, context}]}} = node, {nil, all_targets?}
          when is_atom(name) and is_atom(context) ->
            {node, {name, all_targets?}}

          {:@, _, [{:all_targets, _, [_value]}]} = node, {used, _all_targets?} ->
            {node, {used, true}}

          node, acc ->
            {node, acc}
        end)

      used || if(all_targets?, do: :all_targets)
    end

    @doc """
    Start an application early in the boot

    Nerves projects have a list of applications that are started before the
    project's own application (`config :nerves, application_sort: [init:
    [...]]`, or `config :shoehorn, init: [...]` with Nerves 1.x). Having the
    network in that list keeps a device reachable when the project's
    application fails to start.

    This appends `app` to such a list if the project has one. Lists that
    aren't literals are left alone, and so are lists that have `app` or
    `:nerves_pack`, which depends on the networking libraries.
    """
    @spec start_early(Igniter.t(), atom()) :: Igniter.t()
    def start_early(igniter, app) when is_atom(app) do
      for {config_app, key_path} <- [{:nerves, [:application_sort, :init]}, {:shoehorn, [:init]}],
          file = init_list_file(igniter, config_app, key_path),
          reduce: igniter do
        igniter ->
          Config.configure(igniter, file, config_app, key_path, [app],
            updater: &append_to_init_list(&1, app)
          )
      end
    end

    defp init_list_file(igniter, config_app, key_path) do
      Enum.find(["target.exs", "config.exs"], fn file ->
        Igniter.exists?(igniter, Path.join("config", file)) and
          Config.configures_key?(igniter, file, config_app, key_path)
      end)
    end

    defp append_to_init_list(zipper, app) do
      case Common.within(zipper, &append_app(&1, app)) do
        {:ok, zipper} -> {:ok, zipper}
        :error -> {:ok, zipper}
      end
    end

    defp append_app(list, app) do
      cond do
        not CodeList.list?(list) -> :error
        in_list?(list, :nerves_pack) or in_list?(list, app) -> :error
        true -> CodeList.append_to_list(list, app)
      end
    end

    defp in_list?(list, app) do
      CodeList.find_list_item_index(list, &Common.nodes_equal?(&1, app)) != nil
    end

    @doc """
    Move to a network interface's configuration

    The zipper needs to be positioned at the list of network interface
    configurations. If `ifname` is in the list, this returns a zipper that's
    positioned at its configuration. I.e., the second element of the
    `{ifname, config}` tuple.
    """
    @spec move_to_interface_config(Zipper.t(), VintageNet.ifname()) ::
            {:ok, Zipper.t()} | :error
    def move_to_interface_config(zipper, ifname) do
      with true <- CodeList.list?(zipper),
           {:ok, zipper} <- CodeList.move_to_list_item(zipper, &interface_entry?(&1, ifname)) do
        CodeTuple.tuple_elem(zipper, 1)
      else
        _ -> :error
      end
    end

    defp interface_entry?(zipper, ifname) do
      with true <- CodeTuple.tuple?(zipper),
           {:ok, first} <- CodeTuple.tuple_elem(zipper, 0) do
        Common.nodes_equal?(first, ifname)
      else
        _ -> false
      end
    end

    defp update_interface(igniter, ifname, entry, update) do
      file = config_file(igniter)

      keep_formatting_if_unchanged(igniter, fn igniter ->
        igniter
        |> add_base_config()
        |> Config.configure(file, :vintage_net, [:config], {:code, [entry]},
          updater: fn zipper ->
            cond do
              not CodeList.list?(zipper) ->
                {:warning, not_a_list_warning(file, ifname, entry)}

              match?({:ok, _}, move_to_interface_config(zipper, ifname)) ->
                {:ok, zipper} = move_to_interface_config(zipper, ifname)
                update_existing(zipper, update)

              true ->
                CodeList.append_to_list(zipper, entry)
            end
          end
        )
      end)
    end

    # Igniter writes code back from its AST even when an update didn't change
    # anything. That reformats what it visited. For example, a list that's
    # on multiple lines but fits on one gets collapsed. If the code in the
    # config file is the same after `fun` as before it, the file's text is
    # restored so that calls that don't need to do anything really don't.
    defp keep_formatting_if_unchanged(igniter, fun) do
      path = "config/#{config_file(igniter)}"
      before = existing_content(igniter, path)
      igniter = fun.(igniter)

      with true <- is_binary(before),
           content when is_binary(content) and content != before <-
             existing_content(igniter, path),
           true <- same_code?(before, content) do
        Igniter.update_file(igniter, path, &Rewrite.Source.update(&1, :content, before))
      else
        _ -> igniter
      end
    end

    defp existing_content(igniter, path) do
      if Igniter.exists?(igniter, path) do
        igniter = Igniter.include_existing_file(igniter, path)

        case Rewrite.source(igniter.rewrite, path) do
          {:ok, source} -> Rewrite.Source.get(source, :content)
          _ -> nil
        end
      end
    end

    defp same_code?(a, b) do
      with {:ok, a} <- Code.string_to_quoted(a),
           {:ok, b} <- Code.string_to_quoted(b) do
        strip_meta(a) == strip_meta(b)
      else
        _ -> false
      end
    end

    defp strip_meta(quoted) do
      Macro.prewalk(quoted, fn
        {form, _meta, args} -> {form, [], args}
        other -> other
      end)
    end

    defp update_existing(zipper, update) do
      case Common.within(zipper, update) do
        {:ok, zipper} -> {:ok, zipper}
        _ -> :error
      end
    end

    defp not_a_list_warning(file, ifname, entry) do
      """
      vintage_net: could not add #{inspect(ifname)} to the network interfaces in
      config/#{file} since the `:config` key of `config :vintage_net` isn't a list
      there. Please add the following to the network interface configurations
      manually if needed:

          #{Sourceror.to_string(entry)}
      """
    end

    # The entry is built as source code and parsed with Sourceror so that it has
    # the same shape as code that's read from a config file.
    defp entry_to_quoted(ifname, config) do
      Sourceror.parse_string!("{#{inspect(ifname)}, #{config_to_string(config)}}")
    end

    defp config_to_string({:code, quoted}), do: Sourceror.to_string(quoted)

    defp config_to_string(config) when is_map(config) and not is_struct(config) do
      {type, rest} =
        config |> Map.to_list() |> Enum.sort() |> Enum.split_with(&match?({:type, _}, &1))

      map_to_string(type ++ rest)
    end

    defp config_to_string(config) when is_list(config), do: map_to_string(config)

    defp map_to_string(pairs) do
      "%{" <> Enum.map_join(pairs, ", ", &pair_to_string/1) <> "}"
    end

    defp pair_to_string({key, value}) when is_atom(key) do
      Macro.inspect_atom(:key, key) <> " " <> term_to_string(value)
    end

    defp pair_to_string({key, value}) do
      term_to_string(key) <> " => " <> term_to_string(value)
    end

    defp term_to_string(term), do: term |> Macro.escape() |> Macro.to_string()
  end
end
