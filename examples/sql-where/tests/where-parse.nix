{ lib, selectLib, whereLib }:
let
  sel = selectLib;
  inherit (whereLib) compile;
in
{
  where-parse = {
    test-simple-eq = {
      expr = (compile "env = 'prod'").__sel;
      expected = "attrs";
    };

    test-simple-eq-payload = {
      expr = (compile "env = 'prod'").a;
      expected = { env = "prod"; };
    };

    test-neq = {
      expr = (compile "env != 'prod'").__sel;
      expected = "not";
    };

    test-neq-inner = {
      expr = (compile "env != 'prod'").selector.a;
      expected = { env = "prod"; };
    };

    test-and = {
      expr = (compile "env = 'prod' AND type = 'host'").__sel;
      expected = "and";
    };

    test-and-count = {
      expr = builtins.length (compile "env = 'prod' AND type = 'host'").selectors;
      expected = 2;
    };

    test-or = {
      expr = (compile "env = 'prod' OR env = 'staging'").__sel;
      expected = "or";
    };

    test-or-count = {
      expr = builtins.length (compile "env = 'prod' OR env = 'staging'").selectors;
      expected = 2;
    };

    test-not = {
      expr = (compile "NOT env = 'prod'").__sel;
      expected = "not";
    };

    test-not-inner-tag = {
      expr = (compile "NOT env = 'prod'").selector.__sel;
      expected = "attrs";
    };

    test-in = {
      expr = (compile "env IN ('prod', 'staging')").__sel;
      expected = "or";
    };

    test-in-count = {
      expr = builtins.length (compile "env IN ('prod', 'staging')").selectors;
      expected = 2;
    };

    test-in-first = {
      expr = (builtins.elemAt (compile "env IN ('prod', 'staging')").selectors 0).a;
      expected = { env = "prod"; };
    };

    test-in-second = {
      expr = (builtins.elemAt (compile "env IN ('prod', 'staging')").selectors 1).a;
      expected = { env = "staging"; };
    };

    test-parens = {
      expr = (compile "(env = 'prod')").__sel;
      expected = "attrs";
    };

    test-complex-and-or = {
      expr = (compile "env = 'prod' AND (type = 'host' OR type = 'vm')").__sel;
      expected = "and";
    };

    test-double-not = {
      expr = (compile "NOT NOT env = 'prod'").__sel;
      expected = "not";
    };

    test-double-not-inner = {
      expr = (compile "NOT NOT env = 'prod'").selector.__sel;
      expected = "not";
    };
  };
}
