{
  inputs ? { },
  lib,
  genAlgebra ? null,
}:
let
  # No-flakes import: resolve gen-algebra from CI flake.lock
  lock = builtins.fromJSON (builtins.readFile ../../ci/flake.lock);
  inherit (lock.nodes.gen-algebra) locked;
  genAlgebraSrc = builtins.fetchTarball {
    url = "https://github.com/${locked.owner}/${locked.repo}/archive/${locked.rev}.zip";
    sha256 = locked.narHash;
  };
  resolvedGenAlgebra =
    if genAlgebra != null then genAlgebra else (inputs.gen-algebra or (import genAlgebraSrc { })).pure;

  constructors = import ./constructors.nix { genAlgebra = resolvedGenAlgebra; };
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
    genAlgebra = resolvedGenAlgebra;
  };
}
