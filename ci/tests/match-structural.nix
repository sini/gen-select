{ lib, selectLib, ... }:
let
  sel = selectLib;
  # Three-level graph: env:prod -> host:web -> user:tux
  mockCtx = {
    data =
      id:
      {
        "env:prod" = {
          type = "env";
          env = "prod";
        };
        "host:web" = {
          type = "host";
          role = "frontend";
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
        "host:web" = "env:prod";
        "user:tux" = "host:web";
      }
      .${id} or null;
    children =
      id:
      {
        "env:prod" = [ "host:web" ];
        "host:web" = [ "user:tux" ];
      }
      .${id} or [ ];
    ancestors =
      id:
      {
        "host:web" = [ "env:prod" ];
        "user:tux" = [
          "host:web"
          "env:prod"
        ];
      }
      .${id} or [ ];
    siblings = _: [ ];
  };
  m = sel.matches;
in
{
  match-structural = {
    test-has-direct-child = {
      expr = m (sel.has (sel.attrs { type = "host"; })) "env:prod" mockCtx;
      expected = true;
    };
    test-has-not-grandchild = {
      expr = m (sel.has (sel.attrs { type = "user"; })) "env:prod" mockCtx;
      expected = false;
    };
    test-has-leaf-node = {
      expr = m (sel.has sel.star) "user:tux" mockCtx;
      expected = false;
    };
    test-within-parent = {
      expr = m (sel.within (sel.attrs { type = "host"; })) "user:tux" mockCtx;
      expected = true;
    };
    test-within-grandparent = {
      expr = m (sel.within (sel.attrs { type = "env"; })) "user:tux" mockCtx;
      expected = true;
    };
    test-within-root = {
      expr = m (sel.within sel.star) "env:prod" mockCtx;
      expected = false;
    };
    test-parent-matches-immediate = {
      expr = m (sel.parentMatches (sel.attrs { type = "host"; })) "user:tux" mockCtx;
      expected = true;
    };
    test-parent-matches-not-grandparent = {
      expr = m (sel.parentMatches (sel.attrs { type = "env"; })) "user:tux" mockCtx;
      expected = false;
    };
    test-parent-matches-root = {
      expr = m (sel.parentMatches sel.star) "env:prod" mockCtx;
      expected = false;
    };
    test-child-sugar = {
      expr = m (sel.child (sel.attrs { type = "env"; }) (sel.attrs { type = "host"; })) "host:web" mockCtx;
      expected = true;
    };
    test-child-sugar-wrong-parent = {
      expr = m (sel.child (sel.attrs { type = "host"; }) (sel.attrs { type = "host"; })) "host:web" mockCtx;
      expected = false;
    };
    test-descendant-sugar = {
      expr = m (sel.descendant (sel.attrs { type = "env"; }) (sel.attrs { type = "user"; })) "user:tux" mockCtx;
      expected = true;
    };
    test-descendant-not-ancestor = {
      expr = m (sel.descendant (sel.attrs { type = "user"; }) (sel.attrs { type = "env"; })) "env:prod" mockCtx;
      expected = false;
    };
  };
}
