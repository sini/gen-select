# E3 (construction-time identity law) + E7 (structural equality & dedup, identity only).
# Uses plain mock entries — sel.entity reads only id_hash + name, so a bare attrset is a
# faithful stand-in here; the real-gen-schema-instance paths live in
# adapter-registry-identity / integration-scope.
{ genSelect, ... }:
let
  sel = genSelect;

  entryA = {
    id_hash = "hash-A";
    name = "axon-01";
    uid = 1;
  };
  # Same identity (id_hash) as entryA, divergent display name — the shape a kind pinning
  # `_identity.keys` to exclude `name` produces.
  entryAName2 = {
    id_hash = "hash-A";
    name = "axon-99";
    uid = 2;
  };
  entryB = {
    id_hash = "hash-B";
    name = "blade-01";
  };

  kindUser = {
    kind = "user";
    options = { };
  };
  kindHost = {
    kind = "host";
    options = { };
  };

  # A value throws iff forcing it fails.
  throws = x: !(builtins.tryEval (builtins.deepSeq x x)).success;
in
{
  flake.tests.constructors-identity = {
    # ---- E3: entity construction ----
    test-entity-payload-shape = {
      expr = sel.entity entryA;
      expected = {
        __sel = "entity";
        id_hash = "hash-A";
        name = "axon-01";
      };
    };
    test-entity-stores-no-entry-field = {
      # The entry (with its methods) is deliberately NOT embedded — keeps == total.
      expr = (sel.entity entryA) ? entry;
      expected = false;
    };
    test-entity-string-throws = {
      expr = throws (sel.entity "axon-01");
      expected = true;
    };
    test-entity-no-idhash-throws = {
      expr = throws (sel.entity { name = "x"; });
      expected = true;
    };
    test-entity-name-defaults-null = {
      expr = (sel.entity { id_hash = "h"; }).name;
      expected = null;
    };

    # ---- E3: kind construction ----
    test-kind-payload-shape = {
      expr = sel.kind kindUser;
      expected = {
        __sel = "kind";
        kind = "user";
      };
    };
    test-kind-string-throws = {
      expr = throws (sel.kind "user");
      expected = true;
    };
    test-kind-missing-options-throws = {
      expr = throws (sel.kind { kind = "user"; });
      expected = true;
    };

    # ---- E7: selectorEq compares identity fields only ----
    test-selectorEq-equal-identity = {
      expr = sel.selectorEq (sel.entity entryA) (sel.entity entryA);
      expected = true;
    };
    test-selectorEq-cross-entry-neq = {
      expr = sel.selectorEq (sel.entity entryA) (sel.entity entryB);
      expected = false;
    };
    test-selectorEq-name-divergence-dedup = {
      # Equal id_hash, differing display name → dedup as equal (identity only).
      expr = sel.selectorEq (sel.entity entryA) (sel.entity entryAName2);
      expected = true;
    };
    test-raw-eq-finer-than-selectorEq = {
      # Raw == wrongly distinguishes on the display-only name; selectorEq does not.
      expr = (sel.entity entryA) == (sel.entity entryAName2);
      expected = false;
    };
    test-entity-selector-is-function-free = {
      # Payload carries no functions — deepSeq never throws, so == stays total.
      expr = builtins.deepSeq (sel.entity entryA) true;
      expected = true;
    };
    test-kind-selectorEq-eq = {
      # kind payload carries no display field — the == fall-through is exact.
      expr = sel.selectorEq (sel.kind kindUser) (sel.kind kindUser);
      expected = true;
    };
    test-kind-selectorEq-neq = {
      expr = sel.selectorEq (sel.kind kindUser) (sel.kind kindHost);
      expected = false;
    };
  };
}
