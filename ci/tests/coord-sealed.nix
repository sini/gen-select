# den-hoag-8hqx0: `adapters.product.coord dim kind entry` at a SEALED COLLISION. The coordinate
# decides an entity identity at one position, so it owes `sel.entity`'s decision (ADR-0034). The
# oracle table as DECIDED arms, every refusal read through `tryEval` (so "REFUSED" also says
# catchable). Which refusal fired is pinned by message in ../tests-error.nix `coord-sealed`; this
# plane pins that the live arms around each refusal still decide.
{
  lib,
  genSelect,
  genSchema,
  genMerge,
  ...
}:
let
  sel = genSelect;
  P = sel.adapters.product;
  F = import ../entity-sealed-fixture.nix {
    inherit
      lib
      genSelect
      genSchema
      genMerge
      ;
  };
  inherit (F)
    kA
    kS1
    kS2
    kS1t
    s1
    s1q
    s1t
    s2
    a
    prod
    prodBlind
    prodA
    prodABlind
    prodInFlight
    prodKindName
    tr
    ;
  m =
    s: id: ctx:
    tr (sel.matches s id ctx);
  slice =
    dim: kind: entry:
    P.inSlice { ${dim} = { inherit kind entry; }; };
in
{
  flake.tests.coord-sealed = {
    # The premise: one stamp, and the three sibling doors refuse the pair, so the fixture reaches the
    # collision.
    test-premise-the-pair-collides = {
      expr = {
        stampsEqual = s1.id_hash == s2.id_hash;
        producerKindEq = tr (genSchema.kindEq kS1 kS2);
        selKind = m (sel.kind kS1) "s2" F.reg;
        selEntity = tr (sel.selectorEq (sel.entity kS1 s1) (sel.entity kS2 s2));
      };
      expected = {
        stampsEqual = true;
        producerKindEq = "REFUSED";
        selKind = "REFUSED";
        selEntity = "REFUSED";
      };
    };

    # C1 · selectorEq at the sealed pair refuses, and so does K1 the separately evaluated twin: its
    # `note` carries a default, open content gen-schema seals per construction (den-hoag-egei0). X3
    # the sealed coordinate against itself, K5 a migrated coordinate: true. Another instance, a
    # different stamp (K6) and a different dimension (K7): false.
    test-c1-selectorEq = {
      expr = {
        pair = tr (sel.selectorEq (P.coord "host" kS1 s1) (P.coord "host" kS2 s2));
        twin = tr (sel.selectorEq (P.coord "host" kS1 s1) (P.coord "host" kS1t s1t));
        self = tr (sel.selectorEq (P.coord "host" kS2 s2) (P.coord "host" kS2 s2));
        other = tr (sel.selectorEq (P.coord "host" kS1 s1) (P.coord "host" kS1 s1q));
        migrated = tr (sel.selectorEq (P.coord "host" kA a) (P.coord "host" kA a));
        diffStamp = tr (sel.selectorEq (P.coord "host" kA a) (P.coord "host" kS1 s1));
        diffDim = tr (sel.selectorEq (P.coord "host" kS1 s1) (P.coord "user" kS1 s1));
      };
      expected = {
        pair = "REFUSED";
        twin = "REFUSED";
        self = true;
        other = false;
        migrated = true;
        diffStamp = false;
        diffDim = false;
      };
    };

    # C2 / C2s · the match at the sealed pair refuses, and so does the selection over the space. K2
    # the coordinate's own cell (X2): true. K3 another instance, X6 a dimension the cell lacks: false.
    test-c2-match = {
      expr = {
        onPair = m (P.coord "host" kS1 s1) "cs2" prod;
        selection = tr (
          builtins.filter (id: sel.matches (P.coord "host" kS1 s1) id prod) [
            "cs2"
            "cs2z"
          ]
        );
        own = m (P.coord "host" kS2 s2) "cs2" prod;
        other = m (P.coord "host" kS1 s1q) "cs2" prod;
        absentDim = m (P.coord "user" kS2 s2) "cs2" prod;
      };
      expected = {
        onPair = "REFUSED";
        selection = "REFUSED";
        own = true;
        other = false;
        absentDim = false;
      };
    };

    # C3 · `inSlice { <dim> = { kind; entry; }; }` at the sealed pair refuses; the coordinate's own
    # slice and the empty slice (X7) decide true. C3w is the stated residue (the argued impossibility
    # at `coord`'s declaration): a kind that is not its entry's kind but mints its mark is taken on
    # the caller's word.
    test-c3-inSlice = {
      expr = {
        pair = m (slice "host" kS1 s1) "cs2" prod;
        own = m (slice "host" kS2 s2) "cs2" prod;
        empty = m (P.inSlice { }) "cs2" prod;
        residueC3w = m (slice "host" kS2 s1) "cs2" prod;
      };
      expected = {
        pair = "REFUSED";
        own = true;
        empty = true;
        residueC3w = true;
      };
    };

    # C4 / X1 · a kind-blind context: a sealed equal stamp refuses, the coordinate's OWN cell included
    # (`kinds` is required in effect for a factor of a compared kind). A migrated coordinate decides
    # on its stamp there (K4b), as on a kind-bearing one (K4); a sealed non-match decides false
    # without reading a kind.
    test-c4-kind-blind = {
      expr = {
        pair = m (P.coord "host" kS1 s1) "cs2" prodBlind;
        ownSealed = m (P.coord "host" kS2 s2) "cs2" prodBlind;
        migrated = m (P.coord "host" kA a) "ca" prodA;
        migratedBlind = m (P.coord "host" kA a) "ca" prodABlind;
        sealedNonMatch = m (P.coord "host" kS1 s1q) "cs2" prodBlind;
      };
      expected = {
        pair = "REFUSED";
        ownSealed = "REFUSED";
        migrated = true;
        migratedBlind = true;
        sealedNonMatch = false;
      };
    };

    # C5 · the retired two-argument form refuses by name when the selector is used, catchably (the
    # eager `seq`); without it, it would hand back a function that aborts uncatchably. The stale
    # one-argument-per-dimension `inSlice { host = entry; }` refuses the same way (CF1).
    test-c5-retired-forms = {
      expr = {
        coordMatched = m (P.coord "host" s2) "cs2" prod;
        isFunction = builtins.isFunction (P.coord "host" kS2);
        threeArgument = m (P.coord "host" kS2 s2) "cs2" prod;
        inSliceStale = m (P.inSlice { host = s2; }) "cs2" prod;
        inSliceStaleSelectorEq = tr (sel.selectorEq (P.inSlice { host = s2; }) (P.inSlice { host = s2; }));
        inSliceNoKind = m (P.inSlice { host.entry = s2; }) "cs2" prod;
      };
      expected = {
        coordMatched = "REFUSED";
        isFunction = true;
        threeArgument = true;
        inSliceStale = "REFUSED";
        inSliceStaleSelectorEq = "REFUSED";
        inSliceNoKind = "REFUSED";
      };
    };

    # C6 · a wrong kind at a DIFFERENT mark on a MIGRATED selector: the match reads no node kind and
    # the stamp decides (the stated residue, `sel.entity`'s E4 in coordinate form). `selectorEq`,
    # which holds both kinds, refuses it.
    test-c6-wrong-kind = {
      expr = {
        matchResidue = m (P.coord "host" kA s2) "cs2" prod;
        selectorEq = tr (sel.selectorEq (P.coord "host" kA s2) (P.coord "host" kS2 s2));
      };
      expected = {
        matchResidue = true;
        selectorEq = "REFUSED";
      };
    };

    # X4 · `coordKinds` survives `sel.not`'s cleared context: the own coordinate under `not` decides
    # false, another instance true, and the collision still refuses rather than negating silently.
    test-x4-under-not = {
      expr = {
        own = m (sel.not (P.coord "host" kS2 s2)) "cs2" prodInFlight;
        other = m (sel.not (P.coord "host" kS1 s1q)) "cs2" prodInFlight;
        pair = m (sel.not (P.coord "host" kS1 s1)) "cs2" prodInFlight;
      };
      expected = {
        own = false;
        other = true;
        pair = "REFUSED";
      };
    };

    # X5 · `mkContext`'s `kinds` given a kind NAME refuses by name where it is read; a migrated
    # coordinate, which reads no node kind, still decides there.
    test-x5-kinds-name = {
      expr = {
        sealed = m (P.coord "host" kS2 s2) "cs2" prodKindName;
        migratedStampOnly = m (P.coord "host" kA s2) "cs2" prodKindName;
      };
      expected = {
        sealed = "REFUSED";
        migratedStampOnly = true;
      };
    };

    # C7 / CF2 · a hand-built selector record reaching an arm that reads its kind: no `kind`, a kind
    # NAME, or a record short of `sealed` refuses by name at an equal stamp, in the `coord` and `entity`
    # arms of the matcher and of `selectorEq` (it aborted uncatchably before); at a different stamp
    # the kind is never read and the answer is false.
    test-c7-hand-built-records =
      let
        base = {
          __sel = "coord";
          dim = "host";
          inherit (s2) id_hash;
          name = "p";
        };
        baseE = removeAttrs base [ "dim" ] // {
          __sel = "entity";
        };
        noSealed = {
          identity = "m";
          name = "host";
        };
      in
      {
        expr = {
          coordNoKind = m base "cs2" prod;
          coordNoKindSelectorEq = tr (sel.selectorEq base base);
          coordKindName = m (base // { kind = "host"; }) "cs2" prod;
          coordKindNoSealed = m (base // { kind = noSealed; }) "cs2" prod;
          coordKindNoSealedSelectorEq = tr (
            sel.selectorEq (base // { kind = noSealed; }) (base // { kind = noSealed; })
          );
          coordNoKindDiffStamp = tr (sel.selectorEq base (base // { id_hash = "z"; }));
          entityNoKind = m baseE "s2" F.reg;
          entityNoKindSelectorEq = tr (sel.selectorEq baseE baseE);
          entityKindName = m (baseE // { kind = "host"; }) "s2" F.reg;
        };
        expected = {
          coordNoKind = "REFUSED";
          coordNoKindSelectorEq = "REFUSED";
          coordKindName = "REFUSED";
          coordKindNoSealed = "REFUSED";
          coordKindNoSealedSelectorEq = "REFUSED";
          coordNoKindDiffStamp = false;
          entityNoKind = "REFUSED";
          entityNoKindSelectorEq = "REFUSED";
          entityKindName = "REFUSED";
        };
      };
  };
}
