{
  genSelect,
  ...
}:
let
  sel = genSelect;
  # A record of the INTENSIONAL SHAPE (Palmer §2.2) — the four fields `isIdentified`'s
  # `when`-limb reads. It is NOT gen-algebra's constructor and no longer bears its name:
  # that constructor is an ENCODER — `mkIntensional : hashIdentity -> registry -> ctor ->
  # args` — so a fixture wearing its name in a three-argument call states a contract the
  # substrate does not have, whatever it evaluates to.
  #
  # ★ WHAT KEEPS A SHAPED RECORD HERE IS THAT THE CELLS CHOOSE THE REGIME AND THE DIGEST,
  # AND AN ENCODER-BUILT VALUE CANNOT LET THEM. Each cell picks its own arm — unmigrated,
  # sealed, or minted with a STATED digest — while the encoder DERIVES its digest from the
  # identity coordinate and emits the minted arm always. That is the whole point of it, and
  # it is exactly what makes it unusable here: `test-minted-same-digest-eq` and
  # `-different-digest-neq` hand-pick `its:aaaa` against `its:bbbb` to drive the two sides
  # of the minted arm, and a derived digest cannot be hand-picked; the unmigrated arm is
  # defined by the ABSENCE of `__mint`, which no constructor call can produce. Constructing
  # a value and overriding its `__mint` would assert about a value the constructor cannot
  # emit while reading as though it could. The secondary cost is the same either way —
  # every fixture would have to carry a mint stub and a registry to exercise a SELECTOR.
  #
  # What would RETIRE these records is the migration that turns a selector's distinguishing
  # content from a caller-supplied lambda into a first-order term the substrate interprets:
  # once that lands the encoder can build them, and the regime stops being a cell's choice.
  intensionalLike = name: closure: fn: {
    inherit name closure fn;
    __functor = self: self.fn;
  };
  mockCtx = {
    data =
      id:
      {
        "a" = {
          x = 1;
        };
      }
      .${id};
    parent = _: null;
    children = _: [ ];
    ancestors = _: [ ];
    siblings = _: [ ];
  };
  m = sel.matches;

  bareFn = id: ctx: true;
  identifiedFn = intensionalLike "always-true" { } (id: ctx: true);
  identifiedFn2 = intensionalLike "always-true" { } (id: ctx: true);
  differentFn = intensionalLike "always-false" { } (id: ctx: false);

  # Fixtures for the two regimes a producer stamps. The records above carry no
  # `__mint` and are therefore UNMIGRATED, which is where every shipped value sits
  # until a producer lands — that arm is what keeps the cells above unchanged.
  mintedFn = digest: fn: (intensionalLike "shared-point" { } fn) // { __mint.minted = digest; };
  unmintableFn =
    fn:
    (intensionalLike "shared-point" { } fn)
    // {
      __mint.unmintable = {
        reason = "distinguishing content is a caller-supplied lambda";
        ctor = "shared-point";
      };
    };
  sealedA = unmintableFn (id: ctx: true);
  sealedB = unmintableFn (id: ctx: false);
in
{
  flake.tests.when = {
    test-bare-callable = {
      expr = m (sel.when bareFn) "a" mockCtx;
      expected = true;
    };
    test-identified-callable = {
      expr = m (sel.when identifiedFn) "a" mockCtx;
      expected = true;
    };
    test-bare-not-identified = {
      expr = sel.isIdentified (sel.when bareFn);
      expected = false;
    };
    test-intensional-identified = {
      expr = sel.isIdentified (sel.when identifiedFn);
      expected = true;
    };
    test-same-name-eq = {
      expr = sel.selectorEq (sel.when identifiedFn) (sel.when identifiedFn2);
      expected = true;
    };
    test-different-name-neq = {
      expr = sel.selectorEq (sel.when identifiedFn) (sel.when differentFn);
      expected = false;
    };
    test-bare-lambda-neq = {
      expr = sel.selectorEq (sel.when (id: ctx: true)) (sel.when (id: ctx: true));
      expected = false;
    };
    test-structural-eq-star = {
      expr = sel.selectorEq sel.star sel.star;
      expected = true;
    };

    # ── conservative equality by identity REGIME ─────────────────────────────
    # `test-same-name-eq` above is the UNMIGRATED arm and is unchanged. The cells
    # below cover the two regimes a producer stamps.

    # THE REPAIR: two values sharing one program point and behaving differently
    # are NOT equal. A program point is constant across a constructor's
    # instances, so the retired `x.name == y.name` called this pair equal.
    test-unmintable-distinct-neq = {
      expr = sel.selectorEq (sel.when sealedA) (sel.when sealedB);
      expected = false;
    };
    # CONTROL, and it is the one that matters: the predicate's failure mode is
    # EMPTINESS, not coarseness. A value compared with ITSELF must be equal, or
    # the relation is false for every pair and the cell above passes for the
    # wrong reason. (The whole value takes the evaluator's cell fast path; a
    # component-wise form would be false even here.)
    test-unmintable-self-eq = {
      expr = sel.selectorEq (sel.when sealedA) (sel.when sealedA);
      expected = true;
    };
    # The precision of that arm is an ALLOCATION ARTEFACT, asserted rather than
    # assumed: two separately-constructed equal-shaped values compare unequal, so
    # the relation merges strictly less than Palmer's Fig. 5 and never more.
    test-unmintable-separately-constructed-neq = {
      expr = sel.selectorEq (sel.when (unmintableFn (id: ctx: true))) (
        sel.when (unmintableFn (id: ctx: true))
      );
      expected = false;
    };
    # The MINTED arm: the digest decides, and it is total in the distinguishing
    # content — so two values with one digest merge even though the records were
    # built separately, which is exactly what the unmintable arm cannot do.
    test-minted-same-digest-eq = {
      expr = sel.selectorEq (sel.when (mintedFn "its:aaaa" (id: ctx: true))) (
        sel.when (mintedFn "its:aaaa" (id: ctx: true))
      );
      expected = true;
    };
    test-minted-different-digest-neq = {
      expr = sel.selectorEq (sel.when (mintedFn "its:aaaa" (id: ctx: true))) (
        sel.when (mintedFn "its:bbbb" (id: ctx: false))
      );
      expected = false;
    };
    # The sealed arm compares the reified value MINUS `__id`: that accessor is what a
    # consumer reads when it DEMANDS an identity, and where nothing is minted it IS the
    # named refusal. Forcing it inside a decision would detonate the very decision the
    # refusal exists to permit, so a poisoned accessor must not disturb the relation.
    test-sealed-comparison-does-not-force-id = {
      expr =
        let
          poison =
            v:
            v
            // {
              __id = throw "identity: 'shared-point' has no mintable identity";
            };
          a = poison (unmintableFn (id: ctx: true));
          b = poison (unmintableFn (id: ctx: false));
        in
        {
          self = sel.selectorEq (sel.when a) (sel.when a);
          distinct = sel.selectorEq (sel.when a) (sel.when b);
        };
      expected = {
        self = true;
        distinct = false;
      };
    };

    # ★ THE STRUCTURAL FALL-THROUGH'S BOUNDARY, PINNED AS MEASURED — this cell asserts a
    # LIMIT, not a fix. `selectorEq`'s last arm is plain Nix `==` on two selector
    # records, so it forces every value reachable in their payloads, and a throwing one
    # aborts rather than deciding.
    #
    # The second reading is why `comparisonSubject` is not the remedy here: `__id` is
    # NOT distinguished — an ordinary payload key aborts IDENTICALLY — so this is a
    # property of structural equality over caller-supplied match specifications, not of
    # the identity regimes. Closing it needs a bounded recursive walk, which is a design
    # decision. If a future change closes it, the first two readings flip together and
    # the boundary comment in `lib/constructors.nix` is what needs rewriting.
    test-structural-fallthrough-forces-its-payload = {
      expr =
        let
          decides = e: (builtins.tryEval e).success;
        in
        {
          withRefusingAccessor = decides (
            sel.selectorEq
              (sel.attrs {
                k = "v";
                __id = throw "identity: no mintable identity";
              })
              (
                sel.attrs {
                  k = "v";
                  __id = throw "identity: no mintable identity";
                }
              )
          );
          # CONTROL: an ordinary key name aborts identically, so `__id` is not special.
          withOrdinaryKey = decides (
            sel.selectorEq
              (sel.attrs {
                k = "v";
                zz = throw "plain";
              })
              (
                sel.attrs {
                  k = "v";
                  zz = throw "plain";
                }
              )
          );
          # CONTROL: no refusing value at all — the arm decides, and decides correctly.
          withNoRefusal = sel.selectorEq (sel.attrs { k = "v"; }) (sel.attrs { k = "v"; });
          withNoRefusalDiffering = sel.selectorEq (sel.attrs { k = "v"; }) (sel.attrs { k = "w"; });
          # CONTROL: the entity branch never reaches the payload, so it is unaffected.
          entityBranchUnaffected = decides (
            sel.selectorEq
              (sel.entity {
                id_hash = "h";
                name = "n";
                __id = throw "identity: no mintable identity";
              })
              (
                sel.entity {
                  id_hash = "h";
                  name = "n";
                  __id = throw "identity: no mintable identity";
                }
              )
          );
        };
      expected = {
        withRefusingAccessor = false;
        withOrdinaryKey = false;
        withNoRefusal = true;
        withNoRefusalDiffering = false;
        entityBranchUnaffected = true;
      };
    };
  };
}
