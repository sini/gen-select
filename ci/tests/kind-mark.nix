# `sel.kind` reads gen-schema's PROVENANCE MARK (ADR-0034), not a shape.
#
# The refusals are the subject of `ci/tests-error.nix`'s `kind-mark` group — `tryEval` discards a
# message, and WHICH refusal fired is the whole point at this seam. What lives here is the arm
# without which a guard that refused everything would score green, and the payload property §2 of
# the spec claims and this landing must not quietly exceed.
{
  genSelect,
  genSchema,
  genMerge,
  ...
}:
let
  sel = genSelect;

  # REAL kinds, out of a real schema, so the mark under test is one gen-schema minted rather than
  # one this file wrote. Test-tier deps reach through the hub; the library itself stays Class A.
  mkSchema =
    _:
    genSchema.evalSchema {
      modules = [
        {
          config.schema.user.options.uid = genMerge.mkOption { type = genMerge.types.int; };
          config.schema.host.options.addr = genMerge.mkOption { type = genMerge.types.str; };
        }
      ];
    };
  schema = mkSchema null;

  # ★ AN INDEPENDENTLY EVALUATED SCHEMA OF IDENTICAL CONTENT, and the second cell below is
  # worthless without it. Nix `==` has a pointer-identity fast path, so two selectors built from the
  # SAME kind-value thunk compare equal no matter what the payload holds — measured: with the
  # payload seeded to carry the whole kind value, the cell stayed GREEN. Two separately evaluated
  # kinds is what makes the comparison structural rather than a pointer check.
  schema2 = mkSchema null;
in
{
  # THE LIVE CONTROL of the whole group, and it is genuinely in: without it a `sel.kind` that
  # refused every input passes every refusal cell in `tests-error.nix` perfectly.
  #
  # It pins the mark's PREFIX and never a literal digest: the digest is a function of this
  # fixture's own preimage, so pinning it would make an unrelated fixture edit read as a mechanism
  # change — and the cell's subject is that a mark is there and came from the `"schemakind"`
  # namespace, not what it hashes to.
  flake.tests.kind-mark.test-a-real-kind-value-is-admitted = {
    expr = {
      carriesAMark = schema.user ? __mint && schema.user.__mint ? minted;
      markNamespace = builtins.substring 0 11 schema.user.__mint.minted;
      selector = sel.kind schema.user;
    };
    expected = {
      carriesAMark = true;
      markNamespace = "schemakind:";
      selector = {
        __sel = "kind";
        identity = schema.user.__mint.minted;
        name = "user";
        sealed = { };
      };
    };
  };

  # ★ THE PAYLOAD STAYS STRUCTURALLY COMPARABLE. It carries the minted identity, the display name
  # and the sealed subjects (den-hoag-l0y (a)) — never the kind value itself — so a kind selector
  # nested under a combinator still dedups through `selectorEq`'s structural `==` fall-through.
  # The arms are driven ACROSS TWO SCHEMA EVALUATIONS, which is what gives them teeth.
  #
  # A builder who stored the kind VALUE instead of its name — the obvious way to make the mark
  # available to a future matcher — breaks `sameKindEq`: a kind value carries lambdas (`__functor`,
  # option checkers), Nix `==` calls two lambdas UNEQUAL rather than throwing, so two selectors over
  # equal-but-separately-evaluated kinds stop deduping and the break is SILENT. Measured on this
  # file: with that payload and both arms drawn from one thunk, the cell was green; drawn from two
  # evaluations it reds. A builder who dropped the kind from the payload reds `crossKindNeq`.
  flake.tests.kind-mark.test-selector-payload-stays-comparable = {
    expr = {
      sameKindEq = sel.selectorEq (sel.kind schema.user) (sel.kind schema2.user);
      crossKindNeq = sel.selectorEq (sel.kind schema.user) (sel.kind schema2.host);
      # `==` across two evaluations decides rather than aborting — the property that makes a kind
      # selector usable as a dedup key at all.
      structuralEq = (sel.kind schema.user) == (sel.kind schema2.user);
    };
    expected = {
      sameKindEq = true;
      crossKindNeq = false;
      structuralEq = true;
    };
  };
}
