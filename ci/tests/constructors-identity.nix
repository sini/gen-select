# E3 (construction-time identity law) + E7 (structural equality & dedup, identity only).
# Uses plain mock entries — sel.entity reads only the entry's id_hash + name (its kind is the
# first argument, a real kind), so a bare attrset is a faithful stand-in here; the
# real-gen-schema-instance paths live in
# adapter-registry-identity / integration-scope.
#
# ★ KIND VALUES ARE THE EXCEPTION, AND ADR-0034 IS WHY. `sel.kind` reads the mint-backed mark
# gen-schema stamps at construction, so a bare attrset is no longer a faithful stand-in for a kind
# — it is precisely the value the mark exists to refuse. The kinds below come out of a real schema.
{
  genSelect,
  genSchema,
  genMerge,
  ...
}:
let
  sel = genSelect;

  # Two real kinds, minted by gen-schema. Their NAMES are what every assertion below turns on, so
  # the schema declares exactly the two this file names and nothing else.
  schema = genSchema.evalSchema {
    modules = [
      {
        config.schema.user.options.uid = genMerge.mkOption { type = genMerge.types.int; };
        config.schema.host.options.addr = genMerge.mkOption { type = genMerge.types.str; };
      }
    ];
  };

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

  kindUser = schema.user;
  kindHost = schema.host;

  # A value throws iff forcing it fails.
  throws = x: !(builtins.tryEval (builtins.deepSeq x x)).success;
in
{
  flake.tests.constructors-identity = {
    # ---- E3: entity construction ----
    test-entity-payload-shape = {
      expr = sel.entity kindUser entryA;
      expected = {
        __sel = "entity";
        id_hash = "hash-A";
        # The entry's kind KEY (den-hoag-l0y (β)), the same record a kind selector carries.
        kind = {
          identity = kindUser.__mint.minted;
          name = "user";
          sealed = { };
        };
        name = "axon-01";
      };
    };
    test-entity-stores-no-entry-field = {
      # The entry (with its methods) is deliberately NOT embedded — keeps == total.
      expr = (sel.entity kindUser entryA) ? entry;
      expected = false;
    };
    # The entry-admission refusals (a string, an attrset without id_hash) and the kind-first
    # refusals are MESSAGE cells in ../tests-error.nix (`entity-admission`): with the kind taken
    # first, a `throws` cell here passes on whichever argument refuses, so it cannot tell them apart.
    test-entity-name-defaults-null = {
      expr = (sel.entity kindUser { id_hash = "h"; }).name;
      expected = null;
    };

    # ---- E3: kind construction ----
    # The key is the minted identity (den-hoag-l0y (a)); `name` is display-only; `sealed` is the
    # kind's sealed subjects, empty for a kind whose every component is migrated.
    test-kind-payload-shape = {
      expr = sel.kind kindUser;
      expected = {
        __sel = "kind";
        identity = kindUser.__mint.minted;
        name = "user";
        sealed = { };
      };
    };
    test-kind-string-throws = {
      expr = throws (sel.kind "user");
      expected = true;
    };
    # Named for what it now checks. It used to be `test-kind-missing-options-throws`, and the
    # value it throws on has not changed — but the REASON has: `? options` is retired, and what
    # refuses this attrset is the absent mark (ADR-0034). A cell whose name claims a property the
    # guard no longer tests is the defect this whole landing is about, one level up.
    test-kind-unmarked-throws = {
      expr = throws (sel.kind { kind = "user"; });
      expected = true;
    };

    # ---- E7: selectorEq compares identity fields only ----
    test-selectorEq-equal-identity = {
      expr = sel.selectorEq (sel.entity kindUser entryA) (sel.entity kindUser entryA);
      expected = true;
    };
    test-selectorEq-cross-entry-neq = {
      expr = sel.selectorEq (sel.entity kindUser entryA) (sel.entity kindUser entryB);
      expected = false;
    };
    test-selectorEq-name-divergence-dedup = {
      # Equal id_hash, differing display name → dedup as equal (identity only).
      expr = sel.selectorEq (sel.entity kindUser entryA) (sel.entity kindUser entryAName2);
      expected = true;
    };
    test-raw-eq-finer-than-selectorEq = {
      # Raw == wrongly distinguishes on the display-only name; selectorEq does not.
      expr = (sel.entity kindUser entryA) == (sel.entity kindUser entryAName2);
      expected = false;
    };
    test-entity-selector-is-function-free = {
      # Payload carries no functions — deepSeq never throws, so == stays total.
      expr = builtins.deepSeq (sel.entity kindUser entryA) true;
      expected = true;
    };
    test-kind-selectorEq-eq = {
      expr = sel.selectorEq (sel.kind kindUser) (sel.kind kindUser);
      expected = true;
    };
    test-kind-selectorEq-neq = {
      expr = sel.selectorEq (sel.kind kindUser) (sel.kind kindHost);
      expected = false;
    };
  };
}
