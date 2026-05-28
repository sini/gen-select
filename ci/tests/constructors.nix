{ lib, selectLib, ... }:
let
  sel = selectLib;
in
{
  flake.tests.constructors = {
    test-star-tag = {
      expr = sel.star.__sel;
      expected = "star";
    };
    test-attrs-tag = {
      expr = (sel.attrs { type = "host"; }).__sel;
      expected = "attrs";
    };
    test-attrs-payload = {
      expr =
        (sel.attrs {
          type = "host";
          env = "prod";
        }).a;
      expected = {
        type = "host";
        env = "prod";
      };
    };
    test-and-tag = {
      expr =
        (sel.and [
          sel.star
          sel.star
        ]).__sel;
      expected = "and";
    };
    test-or-tag = {
      expr =
        (sel.or [
          sel.star
          sel.star
        ]).__sel;
      expected = "or";
    };
    test-not-tag = {
      expr = (sel.not sel.star).__sel;
      expected = "not";
    };
    test-has-tag = {
      expr = (sel.has sel.star).__sel;
      expected = "has";
    };
    test-within-tag = {
      expr = (sel.within sel.star).__sel;
      expected = "within";
    };
    test-parentMatches-tag = {
      expr = (sel.parentMatches sel.star).__sel;
      expected = "parentMatches";
    };
    test-when-tag = {
      expr = (sel.when (id: ctx: true)).__sel;
      expected = "when";
    };
    test-child-desugars-to-and = {
      expr = (sel.child (sel.attrs { type = "env"; }) (sel.attrs { type = "host"; })).__sel;
      expected = "and";
    };
    test-child-contains-parentMatches = {
      expr =
        let
          s = sel.child (sel.attrs { type = "env"; }) (sel.attrs { type = "host"; });
        in
        builtins.any (sub: sub.__sel == "parentMatches") s.selectors;
      expected = true;
    };
    test-descendant-desugars-to-and = {
      expr = (sel.descendant (sel.attrs { type = "env"; }) (sel.attrs { type = "host"; })).__sel;
      expected = "and";
    };
    test-descendant-contains-within = {
      expr =
        let
          s = sel.descendant (sel.attrs { type = "env"; }) (sel.attrs { type = "host"; });
        in
        builtins.any (sub: sub.__sel == "within") s.selectors;
      expected = true;
    };
    test-star-structural-eq = {
      expr = sel.star == sel.star;
      expected = true;
    };
    test-attrs-structural-eq = {
      expr = sel.attrs { x = 1; } == sel.attrs { x = 1; };
      expected = true;
    };
    test-attrs-structural-neq = {
      expr = sel.attrs { x = 1; } == sel.attrs { x = 2; };
      expected = false;
    };
  };
}
