# Caller-function totality (den-hoag-g8lo): every caller-supplied function formal owes a
# door-or-falsifier per failure mode (non-function, wrong return, under-application, pattern
# formal). O1/O2/O4/O6/O7/O8 of specs/2026-09-16-gen-select-adapter-defaults-spec.md §3 — the
# uncatchable pattern-formal falsifiers (O3/O9) live on ../tests-error.nix, the only output the
# batch asserter behind checks.default does not force.
{ genSelect, ... }:
let
  sel = genSelect;

  throws = x: !(builtins.tryEval (builtins.deepSeq x x)).success;

  # ---- scope adapter: entryFor ----
  idHashNode = {
    id = "n1";
    type = "x";
    parent = null;
    id_hash = "h-n1"; # identity-bearing at its own top level — the new default's target.
    decls = { };
  };
  declsEntryOnlyNode = {
    id = "n1";
    type = "x";
    parent = null;
    decls.__entry = {
      id_hash = "h-old";
    }; # den-hoag-shaped — the OLD default read this; the new one must not.
  };
  baseScope = {
    node = _: idHashNode;
    get = _: _: throw "get unused in these tests";
  };
in
{
  flake.tests.adapter-totality = {
    # ---- O1: entryFor mode A (non-function) — was uncatchable, now a caught door ----
    test-entryfor-nonfunction-throws = {
      expr =
        let
          ctx = sel.adapters.scope.mkContext (baseScope // { entryFor = "not-a-function"; });
        in
        throws (ctx.data "n1").__identity;
      expected = true;
    };

    # ---- O2: entryFor modes B/C — regression, already-caught before this build, unchanged ----
    test-entryfor-wrong-return-still-throws = {
      expr =
        let
          ctx = sel.adapters.scope.mkContext (baseScope // { entryFor = _: "not-an-entry"; });
        in
        throws (ctx.data "n1").__identity;
      expected = true;
    };
    test-entryfor-underapplied-still-throws = {
      expr =
        let
          ctx = sel.adapters.scope.mkContext (baseScope // { entryFor = _a: _b: null; });
        in
        throws (ctx.data "n1").__identity;
      expected = true;
    };

    # ---- O4: the default no longer reads decls.__entry; it reads the node's own id_hash ----
    test-default-entryfor-reads-node-id-hash = {
      expr =
        let
          ctx = sel.adapters.scope.mkContext baseScope; # no explicit entryFor: the default
        in
        (ctx.data "n1").__identity.id_hash;
      expected = "h-n1";
    };
    test-default-entryfor-ignores-decls-entry = {
      expr =
        let
          ctx = sel.adapters.scope.mkContext {
            node = _: declsEntryOnlyNode;
            get = _: _: throw "get unused in these tests";
          }; # no explicit entryFor: the default no longer finds decls.__entry
        in
        (ctx.data "n1").__identity;
      expected = null;
    };

    # ---- O6/O7/O8: coordsFor — no default, but the required formal was doorless; now doored ----
    test-coordsfor-nonfunction-throws = {
      expr =
        let
          ctx = sel.adapters.product.mkContext {
            cellIds = [ "c1" ];
            coordsFor = "not-a-function";
          };
        in
        throws (ctx.data "c1").__coords;
      expected = true;
    };
    test-coordsfor-wrong-return-throws = {
      expr =
        let
          ctx = sel.adapters.product.mkContext {
            cellIds = [ "c1" ];
            coordsFor = _: "oops-a-string";
          };
        in
        throws (ctx.data "c1").__coords;
      expected = true;
    };
    # Before this build this was a SILENT WRONG MATCH ({success=true; value=false;}), not a
    # throw at all — the sharpest fact this spec carries (§2.3). Assert the throw through the
    # matcher too, not only through direct __coords access.
    test-coordsfor-wrong-return-throws-through-match = {
      expr =
        let
          ctx = sel.adapters.product.mkContext {
            cellIds = [ "c1" ];
            coordsFor = _: "oops-a-string";
          };
        in
        throws (sel.matches (sel.adapters.product.coord "host" { id_hash = "h1"; }) "c1" ctx);
      expected = true;
    };
    test-coordsfor-underapplied-throws = {
      expr =
        let
          ctx = sel.adapters.product.mkContext {
            cellIds = [ "c1" ];
            coordsFor = _a: _b: {
              host = {
                id_hash = "h1";
              };
            };
          };
        in
        throws (ctx.data "c1").__coords;
      expected = true;
    };
  };
}
