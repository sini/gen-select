{
  lib,
  selectLib,
  genAlgebra,
  ...
}:
let
  sel = selectLib;
  inherit (genAlgebra) mkIntensional intensionalEq;
  mockCtx = {
    data =
      id:
      {
        "a" = {
          x = 1;
        };
      }
      .${id};
    parent = _: null;
    children = _: [ ];
    ancestors = _: [ ];
    siblings = _: [ ];
  };
  m = sel.matches;

  bareFn = id: ctx: true;
  identifiedFn = mkIntensional "always-true" { } (id: ctx: true);
  identifiedFn2 = mkIntensional "always-true" { } (id: ctx: true);
  differentFn = mkIntensional "always-false" { } (id: ctx: false);
in
{
  flake.tests.when = {
    test-bare-callable = {
      expr = m (sel.when bareFn) "a" mockCtx;
      expected = true;
    };
    test-identified-callable = {
      expr = m (sel.when identifiedFn) "a" mockCtx;
      expected = true;
    };
    test-bare-not-identified = {
      expr = sel.isIdentified (sel.when bareFn);
      expected = false;
    };
    test-intensional-identified = {
      expr = sel.isIdentified (sel.when identifiedFn);
      expected = true;
    };
    test-same-name-eq = {
      expr = sel.selectorEq (sel.when identifiedFn) (sel.when identifiedFn2);
      expected = true;
    };
    test-different-name-neq = {
      expr = sel.selectorEq (sel.when identifiedFn) (sel.when differentFn);
      expected = false;
    };
    test-bare-lambda-neq = {
      expr = sel.selectorEq (sel.when (id: ctx: true)) (sel.when (id: ctx: true));
      expected = false;
    };
    test-structural-eq-star = {
      expr = sel.selectorEq sel.star sel.star;
      expected = true;
    };
  };
}
