# A kind is keyed by its MINTED identity, never its display name (den-hoag-l0y, owner ruling (a),
# 2026-09-25). The fixture is the pair the name key conflated: two `host` kinds out of two
# `evalSchema` calls, `A` = `{ addr }` and `B` = `{ addr; tags }`. gen-schema's own `kindEq` calls
# them two declarations; before this landing `selectorEq` called them one and `sel.kind A` matched a
# B node. Every cell carries the arm that would pass a library which refused, or never matched,
# everything: an independently evaluated twin of A, and a kind of another name.
#
# The refusal MESSAGES live in `ci/tests-error.nix`'s `kind-identity` group; `tryEval` discards a
# message, and which refusal fired is the point there.
{
  lib,
  genSelect,
  genSchema,
  genMerge,
  ...
}:
let
  sel = genSelect;
  inherit (genSchema) mkInstanceRegistry kindEq;

  declA = {
    addr = genMerge.mkOption { type = genMerge.types.str; };
  };
  declB = declA // {
    tags = genMerge.mkOption {
      type = genMerge.types.listOf genMerge.types.str;
      default = [ ];
    };
  };
  mkHost = d: (genSchema.evalSchema { modules = [ { config.schema.host.options = d; } ]; }).host;
  kA = mkHost declA;
  kA2 = mkHost declA; # the twin: same declaration, separately evaluated
  kB = mkHost declB;
  kUser =
    (genSchema.evalSchema {
      modules = [
        { config.schema.user.options.uid = genMerge.mkOption { type = genMerge.types.int; }; }
      ];
    }).user;

  # ADR-0034's sealed limb: an option typed with a nixpkgs `lib.types` type is UNMIGRATED, so the
  # component is sealed and the mark cannot tell `str` from `int`. gen-schema's `kindEq` REFUSES the
  # pair by name; a comparison of marks alone would call it one kind.
  mkSealed = t: mkHost { addr = genMerge.mkOption { type = t; }; };
  kS = mkSealed lib.types.str;
  kI = mkSealed lib.types.int;
  kS2 = mkSealed lib.types.str; # the sealed twin: same nixpkgs type value
  kG = mkSealed genMerge.types.int; # the migrated control beside kS's shape

  ev = genMerge.evalModuleTree {
    modules = [
      {
        options.hostsA = mkInstanceRegistry kA { };
        options.hostsB = mkInstanceRegistry kB { };
        config.hostsA.axon.addr = "10.0.0.1";
        config.hostsB.axon.addr = "10.0.0.1";
      }
    ];
  };
  nodeData = {
    a = ev.config.hostsA.axon;
    b = ev.config.hostsB.axon;
  };
  ctx = sel.adapters.registry.mkContext {
    nodes = [
      "a"
      "b"
    ];
    data = id: nodeData.${id};
    parent = _: null;
    kindFor = id: if id == "a" then kA else kB;
  };

  throws = x: !(builtins.tryEval (builtins.deepSeq x x)).success;
in
{
  flake.tests.kind-identity = {
    # C1 · the dedup relation is gen-schema's. The A/B pair is what reds a name key; the twin alone
    # would pass one (A vs A' is `true` either way).
    test-selectorEq-agrees-with-kindEq = {
      expr = {
        pair = sel.selectorEq (sel.kind kA) (sel.kind kB) == kindEq kA kB;
        pairValue = sel.selectorEq (sel.kind kA) (sel.kind kB);
        twin = sel.selectorEq (sel.kind kA) (sel.kind kA2);
        otherName = sel.selectorEq (sel.kind kA) (sel.kind kUser);
      };
      expected = {
        pair = true;
        pairValue = false;
        twin = true;
        otherName = false;
      };
    };

    # C1s · a sealed collision is REFUSED, as `kindEq` refuses it, never collapsed to `true`. The
    # live arms: the migrated pair decides `false`, the sealed twin decides `true`.
    test-sealed-collision-refused = {
      expr = {
        marksEqual = kS.__mint.minted == kI.__mint.minted;
        kindEqRefused = throws (kindEq kS kI);
        selectorEqRefused = throws (sel.selectorEq (sel.kind kS) (sel.kind kI));
        migrated = sel.selectorEq (sel.kind kS) (sel.kind kG);
        sealedTwin = sel.selectorEq (sel.kind kS) (sel.kind kS2);
      };
      expected = {
        marksEqual = true;
        kindEqRefused = true;
        selectorEqRefused = true;
        migrated = false;
        sealedTwin = true;
      };
    };

    # Kind selectors nested under a combinator reach `selectorEq`'s structural `==` fall-through.
    # Equal declarations evaluated twice must still dedup (a migrated kind's sealed map is empty);
    # a sealed collision there reads `false` — the conservative direction, never `true`.
    test-nested-dedup = {
      expr = {
        sameValue = sel.selectorEq (sel.not (sel.kind kA)) (sel.not (sel.kind kA2));
        distinct = sel.selectorEq (sel.not (sel.kind kA)) (sel.not (sel.kind kB));
        sealedCollision = sel.selectorEq (sel.not (sel.kind kS)) (sel.not (sel.kind kI));
      };
      expected = {
        sameValue = true;
        distinct = false;
        sealedCollision = false;
      };
    };

    # C2 · `sel.kind A` does not match a node of B. Its green arm alone would pass a matcher that
    # never matches, so the A node and the B selector are in the same cell.
    test-match-by-identity = {
      expr = {
        aOnA = sel.matches (sel.kind kA) "a" ctx;
        aOnB = sel.matches (sel.kind kA) "b" ctx;
        bOnB = sel.matches (sel.kind kB) "b" ctx;
        twinOnA = sel.matches (sel.kind kA2) "a" ctx;
      };
      expected = {
        aOnA = true;
        aOnB = false;
        bOnB = true;
        twinOnA = true;
      };
    };

    # K3 decides through the same helper: a node whose kind is sealed-colliding with the selector's
    # is refused, not matched. Live arm: the node's own kind matches it.
    test-match-sealed-collision-refused = {
      expr =
        let
          evS = genMerge.evalModuleTree {
            modules = [
              {
                options.hs = mkInstanceRegistry kS { };
                config.hs.axon.addr = "10.0.0.1";
              }
            ];
          };
          c = sel.adapters.registry.mkContext {
            nodes = [ "axon" ];
            data = id: evS.config.hs.${id};
            parent = _: null;
            kind = kS;
          };
        in
        {
          own = sel.matches (sel.kind kS) "axon" c;
          collision = throws (sel.matches (sel.kind kI) "axon" c);
        };
      expected = {
        own = true;
        collision = true;
      };
    };

    # C3 · a bare-name `kindFor` is refused (catchably); a kind-value `kindFor` answers.
    test-bare-name-kindfor-refused = {
      expr =
        let
          mk =
            kindFor:
            sel.adapters.registry.mkContext {
              nodes = [ "a" ];
              data = id: nodeData.${id};
              parent = _: null;
              inherit kindFor;
            };
        in
        {
          bare = throws (sel.matches (sel.kind kA) "a" (mk (_: "host")));
          value = sel.matches (sel.kind kA) "a" (mk (_: kA));
        };
      expected = {
        bare = true;
        value = true;
      };
    };

    # C6 · the payload: the minted identity is the key, the name rides along for display.
    test-payload-shape = {
      expr = {
        names = builtins.attrNames (sel.kind kA);
        display = (sel.kind kA).name;
        isTheMark = (sel.kind kA).identity == kA.__mint.minted;
      };
      expected = {
        names = [
          "__sel"
          "identity"
          "name"
          "sealed"
        ];
        display = "host";
        isTheMark = true;
      };
    };
  };
}
