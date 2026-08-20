# gen-select takes ONE library dependency: gen-algebra, for the identity-regime discipline
# `selectorEq` reads. Nothing else — no nixpkgs.lib, which was always unused.
#
# ★ THE ZERO-DEPENDENCY CLAIM IS RETIRED KNOWINGLY, not eroded. It held while conservative
# equality was `a.name == b.name` and the vendored copy really was the "one trivial line"
# the old note priced. It stopped holding when the relation became a dispatch over a tagged
# sum with a mint comparison on one arm: a ~40-line discipline in four libraries is four
# readers of one sum that can drift apart, and gen-algebra is the one that AUTHORS the tag.
# gen-algebra declares no inputs of its own, so a consumer of gen-select gains a leaf and
# no closure — which is what makes the edge cheap enough to be worth the consolidation.
#
# Takes its dependency as a named argument: `import ./lib { algebra = <gen-algebra.lib>; }`.
{ algebra }:
let
  constructors = import ./constructors.nix { inherit algebra; };
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
