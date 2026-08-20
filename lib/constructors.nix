let
  # The ONE access discipline over the three identity regimes, and it is TOTAL OVER
  # THOSE THREE REGIMES — not over the two populations of the migration window, which
  # is the narrower claim it replaced and which omits the sealed regime entirely.
  # `__mint` is a TAGGED SUM, so no reader may branch on FIELD PRESENCE and then read
  # `.minted` raw: on a value that has no mintable identity `v ? __mint` holds and
  # `.minted` is absent, and that read aborts uncatchably rather than refusing.
  #
  #   minted     — an identity over a preimage total in the value's distinguishing
  #                content; consumable as a key, an endpoint or an override handle.
  #   unmintable — no identity AND no substitute. A decision compares the reified
  #                value; a consumer demanding an identity is refused by name.
  #   unmigrated — the migration window: no producer has stamped this value, so the
  #                shipped program-point name is still all a decision has.
  #
  # PRIVATE. The dispatch is a discipline every reader in this library goes through,
  # not a surface consumers select on.
  identityOf =
    v:
    if v ? __mint && v.__mint ? minted then
      { inherit (v.__mint) minted; }
    else if v ? __mint then
      { inherit (v.__mint) unmintable; }
    else
      { unmigrated = v.name; };

  # The comparison SUBJECT for the sealed arm: the reified value MINUS `__id`, and
  # minus nothing else. `__id` is the ACCESSOR a consumer reads when it DEMANDS an
  # identity, and in the sealed regime that accessor is the named refusal itself — so
  # it is not distinguishing content, and forcing it inside a comparison detonates the
  # decision the refusal exists to permit. Removing the field rather than making it
  # absent is what keeps the refusal reachable for a consumer that does demand one.
  #
  # `removeAttrs` preserves the evaluator's cell fast path (measured: a value compared
  # with itself through it stays equal, and two separately-built values stay unequal),
  # so this excludes the accessor without emptying the relation.
  #
  # ★ WHY EXCLUDING `__id` IS SUFFICIENT AND NOT ARBITRARY. It is the only OTHER
  # refusal-valued accessor a compared value can carry, because `__mint.minted` is
  # shielded by the tagged sum's own shape: the minted and sealed arms live under
  # DIFFERENT KEY NAMES, and Nix `==` decides on the name set before forcing any value.
  # Measured, with its control: a throwing payload under a differently-named key is
  # never reached, while the SAME name on both sides DOES force — so the short-circuit
  # is the name check, not throws being ignored. Two sealed values carry inert payloads
  # under one name, so nothing forces there either. The one path that does force a mint
  # is a minted-against-minted comparison, and that arm never reaches here: it compares
  # digests, which is a genuine DEMAND for an identity, where a catchable named refusal
  # is the correct outcome rather than a hazard.
  comparisonSubject = v: removeAttrs v [ "__id" ];
in
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
      let
        isIntensional = v: builtins.isAttrs v && v ? name && v ? __functor && v ? closure;
        # CONSERVATIVE EQUALITY (Palmer's own term, §2.3/§5.3). Palmer's Fig. 5 is a
        # CONJUNCTION over identity AND closure, and the relation this replaces shipped
        # the first conjunct alone: `name` is the PROGRAM POINT, constant across a
        # constructor's instances, so comparing it alone calls behaviourally distinct
        # values equal — the coarsening direction §2.3 forbids. What replaces it is not
        # a second conjunct but the regime dispatch: a minted identity is already total
        # over the distinguishing content, and where nothing is minted the decision
        # compares THE REIFIED VALUE ITSELF.
        #
        # It must be the whole value minus `comparisonSubject`'s ONE exclusion, and
        # never a list of components. An attribute selection is an indirection, so a
        # component-wise form is false even against itself and the relation would be
        # EMPTY rather than finer. The whole-value form takes the evaluator's cell fast
        # path instead: two selectors reaching one value compare equal. Its precision is
        # therefore an ALLOCATION ARTEFACT — two separately-constructed equal-shaped
        # values compare unequal — which merges strictly less than Fig. 5 and never
        # more. For a relation that merely merges work that is the safe direction.
        conservativeEq =
          x: y:
          let
            ix = identityOf x;
            iy = identityOf y;
          in
          if ix ? minted && iy ? minted then
            ix.minted == iy.minted
          else if ix ? unmigrated && iy ? unmigrated then
            ix.unmigrated == iy.unmigrated
          else
            comparisonSubject x == comparisonSubject y;
      in
      if isIntensional a.fn && isIntensional b.fn then conservativeEq a.fn b.fn else false
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
