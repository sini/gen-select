{
  mkContext =
    {
      nodes,
      data,
      parent,
      # The registry's kind VALUE (e.g. schema.user). Registries are per-kind by
      # construction (mkInstanceRegistry kindValue { … }), so it is always in the
      # caller's hand. Real gen-schema instances carry no type/kind field of their
      # own, so kind projection CANNOT default from the datum — omitting `kind` and
      # `kindFor` projects kind = null and any sel.kind match throws (loud, not the
      # A1 silent-never-match). Validated with the same structural guard as sel.kind.
      kind ? null,
      # id -> entry | null. Default suits the common case where `data id` IS the
      # entry (gen-schema instances carry id_hash, so identity is the datum itself).
      entryFor ? (
        id:
        let
          d = data id;
        in
        if d ? id_hash then d else null
      ),
      # id -> kindValue | kindName | null. Default = the constant registry kind (every
      # node in a per-kind registry projects that kind); heterogeneous unions pass an
      # explicit per-id accessor. Accepts a kind value (preferred, identity law) or a
      # bare name (internal convenience); normalized to name below.
      kindFor ? (_: kind),
    }:
    let
      validatedKind =
        if kind == null then
          null
        else if builtins.isAttrs kind && kind ? kind && kind ? options then
          kind
        else
          throw "gen-select: adapters.registry.mkContext `kind` expects a kind value (an attrset with `kind` and `options`, e.g. schema.user) or null; got ${builtins.typeOf kind}.";
      normalizeKind =
        k:
        if k == null then
          null
        else if builtins.isAttrs k then
          k.kind
        else
          k;
    in
    # Force the kind-value guard when the caller relies on it (seq to WHNF): a
    # malformed `kind` argument throws as soon as the context is used.
    builtins.seq validatedKind {
      inherit parent;
      # Same __identity record (or null) as the scope adapter, merged last over the
      # passed-through datum. `kind` is the normalized kindFor result (default: the
      # constant registry kind); a malformed entryFor result surfaces at first id_hash
      # access, and does not block kind matching (kind never reads the entry).
      data =
        id:
        (data id)
        // {
          __identity =
            let
              e = entryFor id;
            in
            if e == null then
              null
            else
              {
                # See the scope adapter: explicit named throw at id_hash access (loud,
                # observable), kind unaffected (it never reads the entry).
                id_hash =
                  if e ? id_hash then
                    e.id_hash
                  else
                    throw "gen-select: entryFor returned a value without id_hash for node ${id}; a registry entry must carry id_hash.";
                kind = normalizeKind (kindFor id);
                entry = e;
              };
        };
      children = id: builtins.filter (nid: parent nid == id) nodes;
      ancestors =
        id:
        let
          go =
            visited: nid:
            let
              p = parent nid;
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
          p = parent id;
        in
        if p == null then
          [ ]
        else
          builtins.filter (cid: cid != id) (builtins.filter (nid: parent nid == p) nodes);
    };
}
