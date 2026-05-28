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
          role = "frontend";
        };
      }
      .${id};
    parent = _: null;
    children = _: [ ];
    ancestors = _: [ ];
    siblings = _: [ ];
  };
  m = sel.matches;
in
{
  flake.tests.composition = {
    test-nested-and-or = {
      expr = m (sel.and [
        (sel.attrs { type = "host"; })
        (sel.or [
          (sel.attrs { env = "dev"; })
          (sel.attrs { env = "prod"; })
        ])
      ]) "host:web" mockCtx;
      expected = true;
    };
    test-nested-and-or-fail = {
      expr = m (sel.and [
        (sel.attrs { type = "host"; })
        (sel.or [
          (sel.attrs { env = "dev"; })
          (sel.attrs { env = "staging"; })
        ])
      ]) "host:web" mockCtx;
      expected = false;
    };
    test-double-negation = {
      expr = m (sel.not (sel.not (sel.attrs { type = "host"; }))) "host:web" mockCtx;
      expected = true;
    };
    test-not-or = {
      expr = m (sel.not (
        sel.or [
          (sel.attrs { type = "user"; })
          (sel.attrs { type = "env"; })
        ]
      )) "host:web" mockCtx;
      expected = true;
    };
    test-and-single = {
      expr = m (sel.and [ (sel.attrs { type = "host"; }) ]) "host:web" mockCtx;
      expected = true;
    };
    test-or-single = {
      expr = m (sel.or [ (sel.attrs { type = "host"; }) ]) "host:web" mockCtx;
      expected = true;
    };
  };
}
