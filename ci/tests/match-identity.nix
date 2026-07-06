# E1 (identity matching), E2 (kind matching; kind-blind loud), E4 (identity-blind loud),
# E5 (non-entity quiet), P4 (staticity/laziness), plus the entry-free dangling cases.
# Hand-built __identity contexts (the enriched-adapter paths live in adapter-*-identity
# and integration-scope).
{ genSelect, ... }:
let
  sel = genSelect;
  m = sel.matches;

  entryU = {
    id_hash = "h-user-sini";
    name = "sini";
  };
  entryU2 = {
    id_hash = "h-user-vic";
    name = "vic";
  };
  kindUser = {
    kind = "user";
    options = { };
  };
  kindHost = {
    kind = "host";
    options = { };
  };

  idMap = {
    u1.__identity = {
      id_hash = "h-user-sini";
      kind = "user";
      entry = entryU;
    };
    u2.__identity = {
      id_hash = "h-user-vic";
      kind = "user";
      entry = entryU2;
    };
    h1.__identity = {
      id_hash = "h-host-axon";
      kind = "host";
      entry = {
        id_hash = "h-host-axon";
        name = "axon";
      };
    };
    plain = {
      __identity = null;
      type = "svc";
    }; # non-entity node
    kindblind.__identity = {
      id_hash = "h-x";
      kind = null; # entity-backed but kind-blind projection
      entry = { id_hash = "h-x"; };
    };
    typed = {
      __identity = null;
      type = "user";
    }; # positional type, no entry
  };
  ctx = {
    data = id: idMap.${id};
    parent = _: null;
    children = id: if id == "root" then [ "u1" "u2" "h1" "plain" ] else [ ];
    ancestors = _: [ ];
    siblings = _: [ ];
  };

  # Legacy identity-blind context — data projects decls only, no __identity key.
  legacyCtx = {
    data = _: { role = "x"; };
    parent = _: null;
    children = _: [ ];
    ancestors = _: [ ];
    siblings = _: [ ];
  };

  # A node whose __identity carries a malformed entry (id_hash access throws), real kind.
  badCtx = {
    data = _: {
      __identity = {
        id_hash = throw "malformed entry: no id_hash";
        kind = "user";
        entry = { };
      };
    };
    parent = _: null;
    children = _: [ ];
    ancestors = _: [ ];
    siblings = _: [ ];
  };

  throws = x: !(builtins.tryEval (builtins.deepSeq x x)).success;
in
{
  flake.tests.match-identity = {
    # ---- E1 ----
    test-entity-hit = {
      expr = m (sel.entity entryU) "u1" ctx;
      expected = true;
    };
    test-entity-miss = {
      expr = m (sel.entity entryU) "u2" ctx;
      expected = false;
    };

    # ---- E2 ----
    test-kind-hit = {
      expr = m (sel.kind kindUser) "u1" ctx;
      expected = true;
    };
    test-kind-miss = {
      expr = m (sel.kind kindHost) "u1" ctx;
      expected = false;
    };

    # ---- E5: non-entity nodes are quiet ----
    test-entity-null-quiet = {
      expr = m (sel.entity entryU) "plain" ctx;
      expected = false;
    };
    test-kind-null-quiet = {
      expr = m (sel.kind kindUser) "plain" ctx;
      expected = false;
    };

    # ---- E2: kind-blind projection throws; entity against the same node still matches ----
    test-kind-blind-throws = {
      expr = throws (m (sel.kind kindUser) "kindblind" ctx);
      expected = true;
    };
    test-entity-through-kindblind = {
      expr = m (sel.entity { id_hash = "h-x"; }) "kindblind" ctx;
      expected = true;
    };

    # ---- type-without-identity: fails sel.kind, passes positional sel.attrs ----
    test-typed-node-fails-kind = {
      expr = m (sel.kind kindUser) "typed" ctx;
      expected = false;
    };
    test-typed-node-attrs = {
      expr = m (sel.attrs { type = "user"; }) "typed" ctx;
      expected = true;
    };

    # ---- E5: composition over mixed entity/non-entity nodes, no throw ----
    test-any-mixed-no-throw = {
      expr = m (sel.any [
        (sel.kind kindUser)
        (sel.kind kindHost)
      ]) "plain" ctx;
      expected = false;
    };
    test-not-over-null = {
      expr = m (sel.not (sel.entity entryU)) "plain" ctx;
      expected = true;
    };
    test-has-mixed = {
      expr = m (sel.has (sel.kind kindUser)) "root" ctx;
      expected = true;
    };

    # ---- E4: identity-blind contexts are loud ----
    test-entity-legacy-throws = {
      expr = throws (m (sel.entity entryU) "anything" legacyCtx);
      expected = true;
    };
    test-kind-legacy-throws = {
      expr = throws (m (sel.kind kindUser) "anything" legacyCtx);
      expected = true;
    };

    # ---- P4: staticity — entity match forces data id only, never children ----
    test-entity-no-force-children = {
      expr =
        let
          lazyCtx = ctx // {
            children = _: throw "sel.entity must not force children";
          };
        in
        m (sel.entity entryU) "u1" lazyCtx;
      expected = true;
    };

    # ---- dangling entries: predicate semantics, absence = no match ----
    test-dangling-entry-no-match = {
      expr = builtins.any (id: m (sel.entity { id_hash = "not-in-graph"; }) id ctx) [
        "u1"
        "u2"
        "h1"
      ];
      expected = false;
    };
    test-stale-generation-no-match = {
      # Same display name, different id_hash (identity field changed) → no rescue by name.
      expr = m (sel.entity {
        id_hash = "h-user-sini-v2";
        name = "sini";
      }) "u1" ctx;
      expected = false;
    };

    # ---- E6 asymmetry (malformed entry): entity forces id_hash → throw; kind still matches ----
    test-malformed-entry-entity-throws = {
      expr = throws (m (sel.entity { id_hash = "whatever"; }) "bad" badCtx);
      expected = true;
    };
    test-malformed-entry-kind-matches = {
      expr = m (sel.kind kindUser) "bad" badCtx;
      expected = true;
    };
  };
}
