{ lib, genSelect, ... }:
let
  sel = genSelect;
  mockCtx = {
    data =
      id:
      {
        "env:prod" = {
          type = "env";
        };
        "host:web" = {
          type = "host";
        };
        "user:tux" = {
          type = "user";
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
  envSel = sel.attrs { type = "env"; };
  hostSel = sel.attrs { type = "host"; };
  userSel = sel.attrs { type = "user"; };
in
{
  flake.tests.sugar = {
    test-child-eq-desugared = {
      expr =
        m (sel.child envSel hostSel) "host:web" mockCtx == m (sel.and [
          hostSel
          (sel.parentMatches envSel)
        ]) "host:web" mockCtx;
      expected = true;
    };
    test-descendant-eq-desugared = {
      expr =
        m (sel.descendant envSel userSel) "user:tux" mockCtx == m (sel.and [
          userSel
          (sel.within envSel)
        ]) "user:tux" mockCtx;
      expected = true;
    };
    test-child-structural-eq = {
      expr =
        sel.child envSel hostSel == sel.and [
          hostSel
          (sel.parentMatches envSel)
        ];
      expected = true;
    };
    test-descendant-structural-eq = {
      expr =
        sel.descendant envSel userSel == sel.and [
          userSel
          (sel.within envSel)
        ];
      expected = true;
    };
  };
}
