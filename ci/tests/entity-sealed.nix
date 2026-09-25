# den-hoag-l0y (β): `sel.entity kindValue entry` at a SEALED COLLISION. The oracle table E1–E6 as
# DECIDED arms, every refusal read through `tryEval` (so "REFUSED" also says catchable). Which
# refusal fired is pinned by message in ../tests-error.nix `entity-sealed`; this plane pins that the
# live arms around each refusal still decide.
{
  lib,
  genSelect,
  genSchema,
  genMerge,
  ...
}:
let
  sel = genSelect;
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
    reg
    blind
    scope
    noKindField
    skew
    tr
    ;
  m =
    s: id: ctx:
    tr (sel.matches s id ctx);
in
{
  flake.tests.entity-sealed = {
    # The premise: one mark, one non-empty sealed key set, the producer refuses, one stamp.
    test-premise-the-pair-collides = {
      expr = {
        marksEqual = kS1.__mint.minted == kS2.__mint.minted;
        sealedKeys = builtins.attrNames kS1.__sealed;
        sealedKeysEqual = builtins.attrNames kS1.__sealed == builtins.attrNames kS2.__sealed;
        migratedSealed = builtins.attrNames kA.__sealed;
        producerKindEq = tr (genSchema.kindEq kS1 kS2);
        stampsEqual = s1.id_hash == s2.id_hash;
      };
      expected = {
        marksEqual = true;
        sealedKeys = [ "options.note.type" ];
        sealedKeysEqual = true;
        migratedSealed = [ ];
        producerKindEq = "REFUSED";
        stampsEqual = true;
      };
    };

    # E1 · selectorEq at the sealed pair refuses; the twin decides true, another instance false.
    test-e1-selectorEq = {
      expr = {
        pair = tr (sel.selectorEq (sel.entity kS1 s1) (sel.entity kS2 s2));
        twin = tr (sel.selectorEq (sel.entity kS1 s1) (sel.entity kS1t s1t));
        other = tr (sel.selectorEq (sel.entity kS1 s1) (sel.entity kS1 s1q));
      };
      expected = {
        pair = "REFUSED";
        twin = true;
        other = false;
      };
    };

    # E2 / E2s · the match at the sealed pair refuses, and so does every selection over it; the
    # entity's own node, its twin and a non-match decide; `sel.kind` refuses the same pair (U1 C-1).
    test-e2-match = {
      expr = {
        onPair = m (sel.entity kS1 s1) "s2" reg;
        onSelf = m (sel.entity kS1 s1) "s1" reg;
        onTwin = m (sel.entity kS1 s1) "s1t" reg;
        onOther = m (sel.entity kS1 s1) "s1q" reg;
        selection = tr (
          builtins.filter (id: sel.matches (sel.entity kS1 s1) id reg) (builtins.attrNames F.nodes)
        );
        kindOnPair = m (sel.kind kS1) "s2" reg;
      };
      expected = {
        onPair = "REFUSED";
        onSelf = true;
        onTwin = true;
        onOther = false;
        selection = "REFUSED";
        kindOnPair = "REFUSED";
      };
    };

    # E3 · kind-blind contexts: a sealed equal stamp refuses (the registry adapter given no kind, the
    # scope adapter, a hand record omitting `kind`); a migrated kind decides on its stamp in all
    # three (A1 preserved), and a sealed non-match decides false without reading a kind.
    test-e3-kind-blind = {
      expr = {
        blindSealed = m (sel.entity kS1 s1) "s1" blind;
        scopeSealed = m (sel.entity kS1 s1) "s1" scope;
        noKindFieldSealed = m (sel.entity kS1 s1) "s1" noKindField;
        blindMinted = m (sel.entity kA a) "a" blind;
        scopeMinted = m (sel.entity kA a) "a" scope;
        noKindFieldMinted = m (sel.entity kA a) "a" noKindField;
        blindSealedNonMatch = m (sel.entity kS1 s1) "s1q" blind;
      };
      expected = {
        blindSealed = "REFUSED";
        scopeSealed = "REFUSED";
        noKindFieldSealed = "REFUSED";
        blindMinted = true;
        scopeMinted = true;
        noKindFieldMinted = true;
        blindSealedNonMatch = false;
      };
    };

    # C-2's sibling on `sel.kind`: a hand record omitting `kind` refuses by name (it aborted
    # uncatchably on the attribute access before); the same node with a kind key decides.
    test-kind-no-kind-field = {
      expr = {
        noKindField = m (sel.kind kS1) "s1" noKindField;
        withKind = m (sel.kind kA) "a" reg;
      };
      expected = {
        noKindField = "REFUSED";
        withKind = true;
      };
    };

    # E4 · a kind that is not the entry's kind: refused where both kinds are in hand. The match arm
    # at a MINTED selector reads no node kind and says true: the stated residue (spec §4.2).
    test-e4-wrong-kind = {
      expr = {
        selectorEq = tr (sel.selectorEq (sel.entity kA s1) (sel.entity kS1 s1));
        matchResidue = m (sel.entity kA s1) "s1" reg;
      };
      expected = {
        selectorEq = "REFUSED";
        matchResidue = true;
      };
    };

    # E5 · the retired one-argument form refuses by name when the selector is used, catchably (the
    # eager `seq`); without it, it would hand back a function that aborts uncatchably.
    test-e5-one-argument-form = {
      expr = {
        matched = m (sel.entity s1) "s1" reg;
        isFunction = builtins.isFunction (sel.entity kS1);
        twoArgument = m (sel.entity kS1 s1) "s1" reg;
      };
      expected = {
        matched = "REFUSED";
        isFunction = true;
        twoArgument = true;
      };
    };

    # E6 · version skew, stood in by hand (a stamp equal to `s1`'s on a node of kind `kA`): a sealed
    # selector refuses (different marks); against gen-schema's real stamps the two differ.
    test-e6-skew = {
      expr = {
        skewed = m (sel.entity kS1 s1) "skew" skew;
        realStampsDiffer = m (sel.entity kS1 s1) "a" reg;
      };
      expected = {
        skewed = "REFUSED";
        realStampsDiffer = false;
      };
    };
  };
}
