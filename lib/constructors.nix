# gen-select's selector constructors.
#
# ★ THE IDENTITY-REGIME DISCIPLINE IS IMPORTED, NOT VENDORED. `identityOf`,
# `comparisonSubject` and `conservativeEq` were written out here in full because gen-select
# declared zero library dependencies, and the copy was priced as "one trivial line" back
# when the relation WAS one line — `a.name == b.name`. It stopped being trivial the moment
# it became a dispatch over a tagged sum with a mint comparison on one arm, and a ~40-line
# discipline duplicated across libraries is how two readers of one tagged sum stop agreeing.
#
# The dependency edge on gen-algebra is taken deliberately and is a knowing change to this
# library's zero-inputs contract: gen-algebra itself declares no inputs, so a consumer gains
# a leaf and no closure. gen-algebra is where the constructor that EMITS the tag lives, which
# makes it the discipline's author rather than just another holder of a copy.
# `identityOf`, `comparisonSubject` and the arm-by-arm reasoning all live with the
# constructor that EMITS the tag; nothing here re-derives them. See
# `gen-algebra/lib/intensional.nix` for why each arm exists, why no reader may branch on
# field presence and read `.minted` raw, and why the sealed arm's comparison subject
# excludes `__id`.
{
  algebra,
  isSchemaKind,
  kindKey,
  kindEq,
  entityEq,
}:
rec {
  star = {
    __sel = "star";
  };

  attrs = a: {
    __sel = "attrs";
    inherit a;
  };

  # Identity selector — matches one specific entity by content-addressed identity.
  # Neron, Tolmach, Visser & Wachsmuth (2015): references resolve to declarations,
  # not to name strings; `id_hash` plays the declaration-position role, so distinct
  # declarations sharing a name never cross-match. Validates structurally at
  # construction (identity law: entries carry identity, strings do not). The entry
  # itself is NOT stored — gen-schema instances carry functions, and embedding them
  # would make Nix `==` on selectors throw, destroying the structural-equality/dedup
  # property every other constructor has.
  #
  # ★ THE ENTRY'S KIND COMES FIRST (den-hoag-l0y (β)): `sel.entity kindValue entry`. gen-schema
  # mints `id_hash` over the kind's MARK, and a mark is minted with a sealed marker at every
  # sealed component, so two kinds differing only there share a mark and their instances share a
  # stamp. The stamp alone therefore cannot decide; the payload stores the kind's KEY
  # (./default.nix `kindKey`) beside it, and `entityEq` refuses such a collision by name as
  # `sel.kind` does. `kindKey`'s fields are shared references, so no mark is forced here.
  entity =
    kindValue:
    let
      # Judged at the FIRST application, as gen-schema's `mkIdentityModule` judges its operand: a
      # stale one-argument call `sel.entity entry` must refuse by name when the selector is used,
      # not hand back a function that aborts uncatchably at `selector.__sel`.
      kind =
        if builtins.isString kindValue then
          throw "gen-select: sel.entity expects the entry's kind value first (sel.entity schema.host hosts.axon), got the string \"${kindValue}\". A kind name is a reference; pass the kind value."
        else if !(isSchemaKind kindValue) then
          throw "gen-select: sel.entity expects the entry's kind value first (sel.entity schema.host hosts.axon): a gen-schema kind value carrying a mint-backed mark (`__mint.minted`, ADR-0034); got ${
            if builtins.isAttrs kindValue && kindValue ? id_hash then
              "an entry (the one-argument form is retired: the entry's kind decides a sealed collision)"
            else if builtins.isAttrs kindValue then
              "an attrset with no mark"
            else
              builtins.typeOf kindValue
          }."
        else
          kindKey kindValue;
    in
    builtins.seq kind (
      entry:
      if builtins.isString entry then
        throw "gen-select: sel.entity expects a registry entry (an attrset carrying id_hash); got a string. Pass the entry value (e.g. den.hosts.axon-01), never a name string."
      else if !(builtins.isAttrs entry && entry ? id_hash) then
        throw "gen-select: sel.entity expects a registry entry (an attrset carrying id_hash); got ${builtins.typeOf entry}."
      else
        {
          __sel = "entity";
          inherit (entry) id_hash;
          inherit kind;
          name = entry.name or null; # display/errors only (identity law); excluded from selectorEq
        }
    );

  # Kind selector — matches all entities of a kind. W3C CSS Selectors Level 4 §5.1:
  # the type (element-name) selector `E`, lifted from element names to schema kinds.
  # Takes a gen-schema kind VALUE and validates its PROVENANCE: the value must carry
  # the mint-backed mark gen-schema stamps at construction (`__mint.minted`, ADR-0034),
  # which is the same read `mkInstanceRegistry` and its three siblings now take.
  #
  # ★ THE KEY IS THE MINTED IDENTITY, NEVER THE NAME (owner-ruled 2026-09-25, den-hoag-l0y
  # (a)). Two kinds sharing a name are two declarations whenever gen-schema's own `kindEq`
  # says so, and a name key conflated them. The payload is ./default.nix's `kindKey`:
  # `identity` (the mark, a shared thunk, so constructing a selector forces nothing),
  # `name` (display and errors only) and `sealed` (the sealed subjects `kindEq` reads).
  # The `sel.entity` precedent, one constructor up, has the same shape: the identity is
  # stored and the name rides along excluded from `selectorEq`.
  #
  # ★ THE GUARD USED TO BE `? kind && ? options`, AND IT CHECKED NOTHING IT NAMED. Any
  # hand-written attrset of that shape was admitted, matched, and was indistinguishable
  # from a real kind under `selectorEq`. See ./kind-mark.nix for the read and for why it
  # is not `algebra.identityOf`.
  kind =
    kindValue:
    if builtins.isString kindValue then
      throw "gen-select: sel.kind expects a kind value (e.g. schema.user), got the string \"${kindValue}\". A kind name is a reference, and resolving it to its declaration needs the shared resolver (den-hoag-7gp66 P1); pass the kind value."
    else if !(builtins.isAttrs kindValue) then
      throw "gen-select: sel.kind expects a gen-schema kind value; got ${builtins.typeOf kindValue}."
    else if !(isSchemaKind kindValue) then
      throw "gen-select: sel.kind expects a gen-schema kind value carrying a mint-backed mark (`__mint.minted`, ADR-0034); got an attrset with no mark. A hand-written `{ kind = ...; options = ...; }` is not a kind value — take the kind from a schema (e.g. `schema.widget`)."
    else
      {
        __sel = "kind";
      }
      // kindKey kindValue;

  and = selectors: {
    __sel = "and";
    inherit selectors;
  };

  any = selectors: {
    __sel = "any";
    inherit selectors;
  };

  not = selector: {
    __sel = "not";
    inherit selector;
  };

  has = selector: {
    __sel = "has";
    inherit selector;
  };

  within = selector: {
    __sel = "within";
    inherit selector;
  };

  parentMatches = selector: {
    __sel = "parentMatches";
    inherit selector;
  };

  child =
    parentSel: childSel:
    and [
      childSel
      (parentMatches parentSel)
    ];

  descendant =
    ancSel: descSel:
    and [
      descSel
      (within ancSel)
    ];

  when = fn: {
    __sel = "when";
    inherit fn;
  };

  isIdentified =
    selector:
    selector.__sel == "when"
    && builtins.isAttrs selector.fn
    && selector.fn ? name
    && selector.fn ? __functor
    && selector.fn ? closure;

  # Canonical dedup relation. Compares identity fields only: the display-only `name`
  # on entity/coord selectors is excluded, so two entries with equal id_hash but
  # differing display names (e.g. a kind pinning `_identity.keys` to exclude name)
  # dedup as equal in neededBy sets and dispatch rule-sets — raw `==` would wrongly
  # distinguish them. `==` is therefore finer than selectorEq exactly on `name`.
  # `kind` payloads compare through gen-schema's `kindEq` relation (./default.nix's `kindEq`):
  # their `name` is display-only too, and a sealed collision is refused by name. `entity`
  # payloads compare through ./default.nix's `entityEq`: the stamp, then the kind by `kindEq`.
  selectorEq =
    a: b:
    if a.__sel == "when" && b.__sel == "when" then
      # CONSERVATIVE EQUALITY — Palmer's own term (§2.3, §5.3), and gen-algebra's binding
      # rather than a copy of it. Fig. 5 is a CONJUNCTION over identity AND closure, and the
      # relation this replaced shipped the first conjunct alone: `name` is the PROGRAM POINT,
      # constant across a constructor's instances, so comparing it alone calls behaviourally
      # distinct values equal — the coarsening direction §2.3 forbids. What replaces it is
      # not a second conjunct but the regime dispatch.
      #
      # The SHAPE GUARD stays here: it is gen-select's own admission test for what counts as
      # an intensional payload on a `when` selector, not part of the identity discipline.
      let
        isIntensional = v: builtins.isAttrs v && v ? name && v ? __functor && v ? closure;
      in
      if isIntensional a.fn && isIntensional b.fn then algebra.conservativeEq a.fn b.fn else false
    else if a.__sel == "entity" && b.__sel == "entity" then
      entityEq "gen-select: selectorEq" a b
    else if a.__sel == "kind" && b.__sel == "kind" then
      kindEq "gen-select: selectorEq" a b
    else if a.__sel == "coord" && b.__sel == "coord" then
      a.dim == b.dim && a.id_hash == b.id_hash
    else
      # ★ STRUCTURAL FALL-THROUGH, AND IT IS NOT AN IDENTITY ARM — read this before
      # routing it through `comparisonSubject` as the three arms above are.
      #
      # This is plain Nix `==` on two whole selector records, so it forces every value
      # reachable in their payloads. A selector whose payload holds a throwing value
      # therefore ABORTS rather than deciding — measured, on
      # `attrs { k = "v"; __id = throw …; }` against a separately-built equal.
      #
      # `comparisonSubject` does NOT discharge that, on two counts, both measured:
      #   1. It strips at the TOP LEVEL, and a selector's keys are `__sel` and its
      #      payload — the `__id` sits one level down inside `a`, and deeper again
      #      through `and`/`has`/`within`. Stripping the selector leaves the abort.
      #   2. `__id` is NOT DISTINGUISHED here: a payload key named `zz` carrying a
      #      throw aborts IDENTICALLY. So this is a property of structural equality
      #      over caller-supplied MATCH-SPECIFICATION data, not of the identity
      #      regimes, and excluding one key name out of infinitely many would signal
      #      that a class was closed when it is not.
      #
      # Closing it properly needs a BOUNDED recursive walk — and an unbounded one over
      # caller data is exactly the class the identity design exists to refuse, since a
      # cyclic or self-referential value overflows uncatchably. That is a design
      # decision rather than a local fix, so this arm stays structural and the boundary
      # is written here. `entity` and `coord` above are unaffected: they compare
      # `id_hash` (and `entity` its kind key) and never reach the entry's payload.
      a == b;
}
