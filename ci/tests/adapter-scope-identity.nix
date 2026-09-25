# E6 (scope-adapter projection coherence, by construction) + E8 (backward-compatible,
# additive enrichment). Mock { node, get } — the real gen-scope.eval path is
# integration-scope.
#
# ★ `sel.kind` OVER THIS ADAPTER IS REFUSED (den-hoag-l0y). A gen-scope node's `type` is a positional
# NAME, not a kind declaration, and kinds are keyed by minted identity; what a gen-scope node's kind
# declaration IS is an open ruling, so until it lands the projection's `kind` refuses by name. The
# three cells that asserted a positive kind match here are refusal cells, each with the live arm that
# still answers (`attrs` on the projected `type`, `sel.entity`). Positive `sel.kind`-over-scope
# coverage is a deferred guarantee against that ruling.
#
# ★ THE `{ node, get }` MOCK STAYS; THE KIND VALUES CANNOT. `sel.kind` reads the mint-backed mark
# gen-schema stamps at construction (ADR-0034), so a bare `{ kind = …; options = { }; }` is the
# value the mark exists to refuse. The two kinds come out of a real schema; what this file measures
# — the scope adapter's projection — is untouched.
{
  genSelect,
  genSchema,
  genMerge,
  ...
}:
let
  sel = genSelect;

  schema = genSchema.evalSchema {
    modules = [
      {
        config.schema.user.options.uid = genMerge.mkOption { type = genMerge.types.int; };
        config.schema.host.options.addr = genMerge.mkOption { type = genMerge.types.str; };
      }
    ];
  };

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
    # Explicit: these fixtures simulate a den-hoag-shaped consumer (identity
    # stashed under decls.__entry, not the node's own top-level id_hash), so
    # entryFor's framework-agnostic default (scope.nix) would not find it.
    entryFor = id: nodeMap.${id}.decls.__entry or null;
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
    test-identity-kind-refused = {
      # The positional type is a name: the projection's `kind` refuses; `type` still carries it.
      expr = {
        refused = throws (ctx.data "user:sini").__identity.kind;
        type = (ctx.data "user:sini").type;
      };
      expected = {
        refused = true;
        type = "user";
      };
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
              project =
                n:
                (n.decls or { })
                // {
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
      expr = sel.matches (sel.entity schema.user entryU) "user:sini" ctx;
      expected = true;
    };
    test-match-kind-through-adapter-refused = {
      expr = {
        refused = throws (sel.matches (sel.kind schema.user) "user:sini" ctx);
        attrs = sel.matches (sel.attrs { type = "user"; }) "user:sini" ctx;
      };
      expected = {
        refused = true;
        attrs = true;
      };
    };
    test-kind-nonentity-false = {
      expr = sel.matches (sel.kind schema.host) "host:axon" ctx;
      expected = false;
    };

    # ---- E6: malformed entryFor result — entity forces id_hash → throw (a MESSAGE cell in
    # ../tests-error.nix, `entity-admission`); kind refuses by its own name, not by the entry
    # (the kind refusal never reads the entry) ----
    test-malformed-entryfor-kind-refused = {
      expr =
        let
          c = sel.adapters.scope.mkContext (
            base
            // {
              entryFor = id: if id == "host:axon" then { name = "axon"; } else null;
            }
          );
        in
        {
          refused = throws (sel.matches (sel.kind schema.host) "host:axon" c);
          attrs = sel.matches (sel.attrs { type = "host"; }) "host:axon" c;
        };
      expected = {
        refused = true;
        attrs = true;
      };
    };
  };
}
