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
{ algebra }:
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
  # property every other constructor has; `id_hash` is content-addressed, so storing
  # it alone loses no identity information.
  entity =
    entry:
    if builtins.isString entry then
      throw "gen-select: sel.entity expects a registry entry (an attrset carrying id_hash); got a string. Pass the entry value (e.g. den.hosts.axon-01), never a name string."
    else if !(builtins.isAttrs entry && entry ? id_hash) then
      throw "gen-select: sel.entity expects a registry entry (an attrset carrying id_hash); got ${builtins.typeOf entry}."
    else
      {
        __sel = "entity";
        inherit (entry) id_hash;
        name = entry.name or null; # display/errors only (identity law); excluded from selectorEq
      };

  # Kind selector — matches all entities of a kind. W3C CSS Selectors Level 4 §5.1:
  # the type (element-name) selector `E`, lifted from element names to schema kinds.
  # Takes a gen-schema kind VALUE (e.g. schema.user) and validates it with the same
  # structural guard mkInstanceRegistry uses (`? kind && ? options`). Stores the kind
  # NAME as the internal key — permitted by the identity law, the input was the kind
  # value; within one context universe the kind name is the kind's identity.
  kind =
    kindValue:
    if builtins.isString kindValue then
      throw "gen-select: sel.kind expects a kind value (e.g. schema.user), got the string \"${kindValue}\". Pass the kind value; strings are internal keys only."
    else if !(builtins.isAttrs kindValue && kindValue ? kind && kindValue ? options) then
      throw "gen-select: sel.kind expects a kind value (an attrset with `kind` and `options`, e.g. schema.user); got ${builtins.typeOf kindValue}."
    else
      {
        __sel = "kind";
        inherit (kindValue) kind;
      };

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
  # `kind` payloads carry no display field, so the `==` fall-through is exact for them.
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
      a.id_hash == b.id_hash
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
      # `id_hash` and never reach the payload.
      a == b;
}
