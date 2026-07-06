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

  # Removed — superseded by `sel.kind <kind-value>`. A one-release throwing stub
  # (deleted the following release) so out-of-tree callers get a named migration
  # path instead of a bare attribute-missing error.
  entityKind =
    _:
    throw ''
      gen-select: sel.entityKind was removed. Use sel.kind <kind-value>
      (e.g. sel.kind schema.user), or sel.attrs { type = "..."; } for bare
      positional typing.'';

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
        # Conservative equality by program point (Palmer §2.3). Inlined from the former
        # gen-algebra.intensionalEq (`a: b: a.name == b.name`) — one trivial line, not
        # worth a library dependency.
        intensionalEq = x: y: x.name == y.name;
      in
      if isIntensional a.fn && isIntensional b.fn then intensionalEq a.fn b.fn else false
    else if a.__sel == "entity" && b.__sel == "entity" then
      a.id_hash == b.id_hash
    else if a.__sel == "coord" && b.__sel == "coord" then
      a.dim == b.dim && a.id_hash == b.id_hash
    else
      a == b;
}
