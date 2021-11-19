# .credo.exs
%{
  configs: [
    %{
      name: "default",
      checks: [
        {Credo.Check.Refactor.MapInto, false},
        {Credo.Check.Warning.LazyLogging, false},
        {Credo.Check.Readability.LargeNumbers, only_greater_than: 86400},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, parens: true},
        # {Credo.Check.Readability.Specs, []},
        {Credo.Check.Readability.StrictModuleLayout, tags: []}
      ]
    }
  ]
}
