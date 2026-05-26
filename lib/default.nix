{
  lib,
  genPure,
}:
let
  constructors = import ./constructors.nix { inherit genPure; };
  match = import ./match.nix { inherit lib; };
  scopeAdapter = import ./adapters/scope.nix { inherit lib; };
  graphAdapter = import ./adapters/graph.nix { inherit (match) matches; };
in
constructors
// {
  inherit (match) matches;
  adapters = {
    scope = scopeAdapter;
    graph = graphAdapter;
  };
  _internal = {
    inherit genPure;
  };
}
