# gen-select has zero library dependencies — builtins only. Conservative equality over
# the three identity regimes is inlined into constructors.nix (`identityOf` +
# `conservativeEq`); the former nixpkgs.lib (always unused) and gen-algebra dependencies
# are gone. The relation is no longer the "one trivial line" the earlier note priced —
# it dispatches on a tagged sum and one of its arms is a mint comparison — but
# gen-select is dependency-free by construction, so the discipline is written here
# rather than imported.
#
# Zero dependencies, so this is a bare value (not a function): `import ./lib`.
let
  constructors = import ./constructors.nix;
  match = import ./match.nix;
  scopeAdapter = import ./adapters/scope.nix;
  graphAdapter = import ./adapters/graph.nix { inherit (match) matches; };
  registryAdapter = import ./adapters/registry.nix;
  productAdapter = import ./adapters/product.nix { inherit (constructors) and; };
in
constructors
// {
  inherit (match) matches;
  adapters = {
    scope = scopeAdapter;
    graph = graphAdapter;
    registry = registryAdapter;
    product = productAdapter;
  };
}
