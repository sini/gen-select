# E6 (scope-adapter projection coherence, by construction) + E8 (backward-compatible,
# additive enrichment). Mock { node, get } — the real gen-scope.eval path is
# integration-scope.
{ genSelect, ... }:
let
  sel = genSelect;

  entryU = {
    id_hash = "h-sini";
    name = "sini";
  };
  nodeMap = {
    "user:sini" = {
      id = "user:sini";
      type = "user";
      parent = "host:axon";
      decls = {
        shell = "/bin/zsh";
        __entry = entryU;
      };
    };
    "host:axon" = {
      id = "host:axon";
      type = "host";
      parent = null;
      decls = {
        role = "server";
      }; # no __entry
    };
  };
  base = {
    node = id: nodeMap.${id};
    get = _: _: throw "get unused in these tests";
  };
  ctx = sel.adapters.scope.mkContext base;

  throws = x: !(builtins.tryEval (builtins.deepSeq x x)).success;
in
{
  flake.tests.adapter-scope-identity = {
    # ---- E6: __identity record on an entity-backed node ----
    test-identity-idhash = {
      expr = (ctx.data "user:sini").__identity.id_hash;
      expected = "h-sini";
    };
    test-identity-kind-from-node-type = {
      # kind is copied from node.type (positional kind authoritative), not from the entry.
      expr = (ctx.data "user:sini").__identity.kind;
      expected = "user";
    };
    test-identity-entry-carried = {
      expr = (ctx.data "user:sini").__identity.entry.name;
      expected = "sini";
    };

    # ---- E6: null iff no __entry; ---- E8: key always present ----
    test-identity-null-when-no-entry = {
      expr = (ctx.data "host:axon").__identity;
      expected = null;
    };
    test-identity-key-present-even-null = {
      expr = (ctx.data "host:axon") ? __identity;
      expected = true;
    };

    # ---- E8: additive superset — old-default projection keys all survive ----
    test-superset-decl-key = {
      expr = (ctx.data "user:sini").shell;
      expected = "/bin/zsh";
    };
    test-superset-type-key = {
      expr = (ctx.data "user:sini").type;
      expected = "user";
    };

    # ---- E6: custom project cannot shadow __identity (reserved-namespace, merge-last) ----
    test-project-cannot-shadow-identity = {
      expr =
        let
          c = sel.adapters.scope.mkContext (
            base
            // {
              project = n: (n.decls or { }) // {
                __identity = "HACKED";
                inherit (n) type;
              };
            }
          );
        in
        (c.data "user:sini").__identity.id_hash;
      expected = "h-sini";
    };

    # ---- E6: explicit entryFor override honored ----
    test-explicit-entryfor = {
      expr =
        let
          c = sel.adapters.scope.mkContext (
            base
            // {
              entryFor =
                id:
                if id == "host:axon" then
                  {
                    id_hash = "h-host";
                    name = "axon";
                  }
                else
                  null;
            }
          );
        in
        (c.data "host:axon").__identity.id_hash;
      expected = "h-host";
    };

    # ---- E1/E2 flow through the enriched adapter ----
    test-match-entity-through-adapter = {
      expr = sel.matches (sel.entity entryU) "user:sini" ctx;
      expected = true;
    };
    test-match-kind-through-adapter = {
      expr = sel.matches (sel.kind {
        kind = "user";
        options = { };
      }) "user:sini" ctx;
      expected = true;
    };
    test-kind-nonentity-false = {
      expr = sel.matches (sel.kind {
        kind = "host";
        options = { };
      }) "host:axon" ctx;
      expected = false;
    };

    # ---- E6: malformed entryFor result — entity forces id_hash → throw; kind still matches ----
    test-malformed-entryfor-entity-throws = {
      expr =
        let
          c = sel.adapters.scope.mkContext (
            base
            // {
              entryFor = id: if id == "host:axon" then { name = "axon"; } else null;
            }
          );
        in
        throws (sel.matches (sel.entity { id_hash = "x"; }) "host:axon" c);
      expected = true;
    };
    test-malformed-entryfor-kind-matches = {
      expr =
        let
          c = sel.adapters.scope.mkContext (
            base
            // {
              entryFor = id: if id == "host:axon" then { name = "axon"; } else null;
            }
          );
        in
        sel.matches (sel.kind {
          kind = "host";
          options = { };
        }) "host:axon" c;
      expected = true;
    };
  };
}
