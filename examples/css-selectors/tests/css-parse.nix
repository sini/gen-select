{
  lib,
  selectLib,
  cssLib,
}:
let
  sel = selectLib;
  inherit (cssLib) parse parseCompound;
in
{
  css-parse = {
    test-star = {
      expr = (parse "*").__sel;
      expected = "star";
    };

    test-bare-name = {
      expr = (parse "app").__sel;
      expected = "attrs";
    };

    test-bare-name-payload = {
      expr = (parse "app").a;
      expected = {
        name = "app";
      };
    };

    test-id-selector = {
      expr = (parse "#myid").a;
      expected = {
        name = "myid";
      };
    };

    test-class-selector = {
      expr = (parse ".active").a;
      expected = {
        class = "active";
      };
    };

    test-attr-eq = {
      expr = (parse "[env=prod]").a;
      expected = {
        env = "prod";
      };
    };

    test-attr-exists = {
      expr = (parse "[env]").__sel;
      expected = "when";
    };

    test-not = {
      expr = (parse ":not(.active)").__sel;
      expected = "not";
    };

    test-not-inner = {
      expr = (parse ":not(.active)").selector.a;
      expected = {
        class = "active";
      };
    };

    test-has = {
      expr = (parse ":has(.child)").__sel;
      expected = "has";
    };

    test-has-inner = {
      expr = (parse ":has(.child)").selector.a;
      expected = {
        class = "child";
      };
    };

    test-within = {
      expr = (parse ":within([env=prod])").__sel;
      expected = "within";
    };

    test-within-inner = {
      expr = (parse ":within([env=prod])").selector.a;
      expected = {
        env = "prod";
      };
    };

    test-child-combinator = {
      expr = (parse "parent > child").__sel;
      expected = "and";
    };

    test-child-combinator-has-parentMatches = {
      expr =
        let
          s = parse "parent > child";
        in
        builtins.any (sub: sub.__sel == "parentMatches") s.selectors;
      expected = true;
    };

    test-descendant-combinator = {
      expr = (parse "ancestor child").__sel;
      expected = "and";
    };

    test-descendant-combinator-has-within = {
      expr =
        let
          s = parse "ancestor child";
        in
        builtins.any (sub: sub.__sel == "within") s.selectors;
      expected = true;
    };

    test-or-combinator = {
      expr = (parse "a, b").__sel;
      expected = "any";
    };

    test-or-combinator-length = {
      expr = builtins.length (parse "a, b").selectors;
      expected = 2;
    };

    test-compound-id-class = {
      expr = (parse "#app.active").__sel;
      expected = "and";
    };

    test-compound-id-class-count = {
      expr = builtins.length (parse "#app.active").selectors;
      expected = 2;
    };

    test-parseCompound-star = {
      expr = (parseCompound "*").__sel;
      expected = "star";
    };

    test-parseCompound-name = {
      expr = (parseCompound "foo").a;
      expected = {
        name = "foo";
      };
    };
  };
}
