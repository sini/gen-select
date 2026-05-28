{ lib, selectLib, ... }:
let
  sel = selectLib;
  mockCtx = {
    data =
      id:
      {
        "host:web" = {
          type = "host";
          env = "prod";
        };
        "user:tux" = {
          type = "user";
          shell = "/bin/zsh";
        };
      }
      .${id};
    parent =
      id:
      {
        "user:tux" = "host:web";
      }
      .${id} or null;
    children =
      id:
      {
        "host:web" = [ "user:tux" ];
      }
      .${id} or [ ];
    ancestors =
      id:
      {
        "user:tux" = [ "host:web" ];
      }
      .${id} or [ ];
    siblings = _: [ ];
  };
  m = sel.matches;
in
{
  flake.tests.match-basic = {
    test-star = {
      expr = m sel.star "host:web" mockCtx;
      expected = true;
    };
    test-attrs-match = {
      expr = m (sel.attrs { type = "host"; }) "host:web" mockCtx;
      expected = true;
    };
    test-attrs-mismatch = {
      expr = m (sel.attrs { type = "user"; }) "host:web" mockCtx;
      expected = false;
    };
    test-attrs-multi = {
      expr = m (sel.attrs {
        type = "host";
        env = "prod";
      }) "host:web" mockCtx;
      expected = true;
    };
    test-attrs-missing-key = {
      expr = m (sel.attrs { nonexistent = "x"; }) "host:web" mockCtx;
      expected = false;
    };
    test-attrs-empty = {
      expr = m (sel.attrs { }) "host:web" mockCtx;
      expected = true;
    };
    test-and-both = {
      expr = m (sel.and [
        (sel.attrs { type = "host"; })
        (sel.attrs { env = "prod"; })
      ]) "host:web" mockCtx;
      expected = true;
    };
    test-and-one-fails = {
      expr = m (sel.and [
        (sel.attrs { type = "host"; })
        (sel.attrs { env = "dev"; })
      ]) "host:web" mockCtx;
      expected = false;
    };
    test-and-empty = {
      expr = m (sel.and [ ]) "host:web" mockCtx;
      expected = true;
    };
    test-or-one-matches = {
      expr = m (sel.or [
        (sel.attrs { type = "user"; })
        (sel.attrs { type = "host"; })
      ]) "host:web" mockCtx;
      expected = true;
    };
    test-or-none = {
      expr = m (sel.or [
        (sel.attrs { type = "user"; })
        (sel.attrs { env = "dev"; })
      ]) "host:web" mockCtx;
      expected = false;
    };
    test-or-empty = {
      expr = m (sel.or [ ]) "host:web" mockCtx;
      expected = false;
    };
    test-not-true = {
      expr = m (sel.not (sel.attrs { type = "user"; })) "host:web" mockCtx;
      expected = true;
    };
    test-not-false = {
      expr = m (sel.not sel.star) "host:web" mockCtx;
      expected = false;
    };
    test-when-true = {
      expr = m (sel.when (id: ctx: (ctx.data id).env == "prod")) "host:web" mockCtx;
      expected = true;
    };
    test-when-false = {
      expr = m (sel.when (id: ctx: (ctx.data id).env == "dev")) "host:web" mockCtx;
      expected = false;
    };
    test-has-child = {
      expr = m (sel.has (sel.attrs { type = "user"; })) "host:web" mockCtx;
      expected = true;
    };
    test-has-no-child = {
      expr = m (sel.has (sel.attrs { type = "host"; })) "host:web" mockCtx;
      expected = false;
    };
    test-within-ancestor = {
      expr = m (sel.within (sel.attrs { type = "host"; })) "user:tux" mockCtx;
      expected = true;
    };
    test-within-no-ancestor = {
      expr = m (sel.within (sel.attrs { type = "user"; })) "host:web" mockCtx;
      expected = false;
    };
    test-parentMatches-match = {
      expr = m (sel.parentMatches (sel.attrs { type = "host"; })) "user:tux" mockCtx;
      expected = true;
    };
    test-parentMatches-root = {
      expr = m (sel.parentMatches sel.star) "host:web" mockCtx;
      expected = false;
    };
  };
}
