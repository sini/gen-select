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
      # id -> entry | null. Default = the decls.__entry registration convention
      # (gen-scope reserves the `__` namespace inside decls, e.g. decls.__edges);
      # den-hoag writes each entity's registry entry at decls.<id>.__entry.
      entryFor ? (id: (node id).decls.__entry or null),
    }:
    {
      # __identity is composed OUTSIDE the projection and merged last, so it is
      # always present (record or null) and a user decl named __identity can never
      # shadow it (reserved-namespace discipline). `kind` is copied from the
      # positional node type — making __identity.kind == node.type a by-construction
      # invariant rather than a cross-source coherence obligation; a malformed
      # `entryFor` result surfaces at the first `id_hash` access (missing attribute),
      # never a silent null, and never blocks kind matching (kind never reads the entry).
      data =
        id:
        let
          n = node id;
        in
        (project n)
        // {
          __identity =
            let
              e = entryFor id;
            in
            if e == null then
              null
            else
              {
                # Surfaces at the first id_hash access (never a silent null); does not
                # block kind matching, which reads only node.type. Raised as an explicit
                # named throw rather than a bare missing-attribute so the loud-failure
                # law stays observable under builtins.tryEval (Nix does not catch native
                # missing-attribute errors).
                id_hash =
                  if e ? id_hash then
                    e.id_hash
                  else
                    throw "gen-select: entryFor returned a value without id_hash for node ${id}; a registry entry must carry id_hash.";
                kind = n.type;
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
