{ isSchemaKind, kindKey }:
{
  mkContext =
    {
      node,
      get,
      # Projection from a scope node to the attrset that `attrs` selectors
      # match against. The default surfaces the node's `type` alongside its
      # decls so positional-type `attrs` matching works out of the box; node
      # type wins over a same-named decl key because positional kind is
      # authoritative.
      project ? (n: (n.decls or { }) // { inherit (n) type; }),
      # id -> entry | null. Default suits the common case where the node ITSELF is
      # identity-bearing (carries id_hash at its own top level) — no framework
      # convention assumed, mirroring the registry adapter's entryFor default
      # (registry.nix, `if d ? id_hash then d else null`). A node whose identity
      # lives elsewhere (e.g. under a framework's own decls key) supplies an
      # explicit entryFor; the substrate never reads a framework's private
      # convention by default (ADR-0035).
      entryFor ? (
        id:
        let
          n = node id;
        in
        if n ? id_hash then n else null
      ),
      # Accessor names (drawn from data/parent/children/ancestors/siblings) that
      # read a graph still under construction. Passed straight through to the
      # returned context for gen-select's discrete/monotone separation
      # (match.nix's discreteCtx) to clear at a non-monotone read. Conservative
      # default: a context that declares nothing in flight is unchanged.
      inFlight ? [ ],
    }:
    {
      inherit inFlight;
      # __identity is composed OUTSIDE the projection and merged last, so it is
      # always present (record or null) and a user decl named __identity can never
      # shadow it (reserved-namespace discipline). `kind` is the node's carried kind
      # value's key, or a named refusal (see below): a positional node type is a
      # name, not a kind declaration, and is never projected as one. A malformed
      # `entryFor` result surfaces at the first `id_hash` access (missing attribute),
      # never a silent null.
      data =
        id:
        let
          n = node id;
        in
        (project n)
        // {
          __identity =
            if !(builtins.isFunction entryFor) then
              throw "gen-select: adapters.scope.mkContext's `entryFor` must be a function (id -> entry | null); got ${builtins.typeOf entryFor}."
            else
              let
                e = entryFor id;
              in
              if e == null then
                null
              else
                {
                  # Surfaces at the first id_hash access (never a silent null). Raised as an explicit
                  # named throw rather than a bare missing-attribute so the loud-failure
                  # law stays observable under builtins.tryEval (Nix does not catch native
                  # missing-attribute errors).
                  id_hash =
                    if e ? id_hash then
                      e.id_hash
                    else
                      throw "gen-select: entryFor returned a value without id_hash for node ${id}; a registry entry must carry id_hash.";
                  # The node's KIND VALUE (den-hoag-l0y, arm (B′)): gen-scope stamps the value
                  # its kind declares (`mkKind { kindValue = schema.<kind>; }`) on every node of
                  # that kind as the record field `kindValue`, and this projects its key exactly
                  # as the registry adapter does (`normalizeKind`/`kindKey`), so `sel.kind` compares
                  # minted identities. A node carrying none is REFUSED by name, lazily: its `type`
                  # is a positional NAME and is never compared as a kind. Lazy, so `attrs` matching
                  # on the projected `type` is unaffected, and so is `sel.entity` for a kind with
                  # no sealed components (the stamp decides alone); at an equal stamp whose kind
                  # HAS sealed components, `sel.entity` demands the node's kind and reaches it.
                  kind =
                    let
                      v = n.kindValue or null;
                    in
                    if isSchemaKind v then
                      kindKey v
                    else if v == null then
                      throw "gen-select: adapters.scope.mkContext: node ${id} (type ${
                        builtins.toJSON (n.type or null)
                      }) carries no kind value; sel.kind, and sel.entity at a stamp whose kind has sealed components, compare minted kind identities. Declare the kind's value on its gen-scope kind (`mkKind { kindValue = schema.<kind>; }`)."
                    else
                      throw "gen-select: adapters.scope.mkContext: node ${id} carries a `kindValue` with no mint-backed mark (`__mint.minted`; a kind's identity comes only from the one mint); a hand-written `{ kind = ...; ... }` is not a kind value.";
                  entry = e;
                };
        };
      parent = id: (node id).parent;
      children = id: builtins.attrNames (get id "children");
      ancestors =
        id:
        let
          go =
            visited: nid:
            let
              p = (node nid).parent;
            in
            if p == null then
              [ ]
            else if visited ? ${p} then
              [ ]
            else
              [ p ] ++ go (visited // { ${p} = true; }) p;
        in
        go { ${id} = true; } id;
      siblings =
        id:
        let
          p = (node id).parent;
        in
        if p == null then [ ] else builtins.filter (cid: cid != id) (builtins.attrNames (get p "children"));
    };
}
