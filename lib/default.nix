# gen-select has zero library dependencies — builtins only. intensionalEq is inlined
# into constructors.nix; the former nixpkgs.lib (always unused) and gen-algebra (one
# trivial function) dependencies are gone.
{ ... }:
let
  constructors = import ./constructors.nix;
  match = import ./match.nix;
  scopeAdapter = import ./adapters/scope.nix;
  graphAdapter = import ./adapters/graph.nix { inherit (match) matches; };
  registryAdapter = import ./adapters/registry.nix;
in
constructors
// {
  inherit (match) matches;
  adapters = {
    scope = scopeAdapter;
    graph = graphAdapter;
    registry = registryAdapter;
  };
}
