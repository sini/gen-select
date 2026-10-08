# The grammar's L1 rows here (den-hoag-7gp66).
# - R10 rule 3: `any` is `anyOf` (gen-prelude's `any` is nixpkgs' `lib.any`). The old name refuses
#   catchably, and its message is pinned by the generated `root-surface-retired.test-retired-any`.
# - R8: `adapters.product.mkContext`'s `cellIds` is `nodeIds`. A retired field is carried nowhere;
#   the door's formals are native and closed, so the old field aborts uncatchably until that door
#   moves to `prelude.door` (stated, not cell-gated).
# - R10 rule 2: `matches` refuses a non-selector by name and catchably. The other members' values of
#   the same names (`scope.star`, `merge.types.attrs`, `merge.types.any`, the `builtins.any` primop
#   gen-prelude re-exports) are the cross-passes.
{
  genSelect,
  genScope,
  genMerge,
  ...
}:
let
  sel = genSelect;
  refuses = v: !(builtins.tryEval (builtins.typeOf v)).success;
  refusedMatch = s: !(builtins.tryEval (sel.matches s "a" ctx)).success;
  ctx = {
    data = id: { type = id; };
    parent = _: null;
    children = _: [ ];
    ancestors = _: [ ];
    siblings = _: [ ];
  };
  m = s: id: sel.matches s id ctx;
in
{
  flake.tests.grammar-renames.test-any-refuses = {
    expr = refuses sel.any;
    expected = true;
  };

  # agree on one input, differ on a control input
  flake.tests.grammar-renames.test-anyOf-serves = {
    expr = [
      (m (sel.anyOf [
        (sel.attrs { type = "a"; })
        (sel.attrs { type = "b"; })
      ]) "a")
      (m (sel.anyOf [
        (sel.attrs { type = "a"; })
        (sel.attrs { type = "b"; })
      ]) "z")
      (sel.anyOf [ ]).__sel
    ];
    expected = [
      true
      false
      "any"
    ];
  };

  flake.tests.grammar-renames.test-nodeIds-serves = {
    expr =
      let
        c = sel.adapters.product.mkContext {
          nodeIds = [
            "x"
            "y"
          ];
          coordsFor = _: { };
          parent = id: if id == "y" then "x" else null;
        };
      in
      c.children "x";
    expected = [ "y" ];
  };

  flake.tests.grammar-renames.test-matches-refuses-a-non-selector = {
    expr = map refusedMatch [
      genScope.star
      genMerge.types.attrs
      genMerge.types.any
      builtins.any
      "star"
      null
    ];
    expected = [
      true
      true
      true
      true
      true
      true
    ];
  };

  # the refusal is nested too: a non-selector inside a combinator is refused at its own read
  flake.tests.grammar-renames.test-matches-refuses-a-nested-non-selector = {
    expr = refusedMatch (
      sel.and [
        sel.star
        { }
      ]
    );
    expected = true;
  };
}
