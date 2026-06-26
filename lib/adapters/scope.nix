{
  mkContext =
    {
      node,
      get,
      # Projection from a scope node to the attrset that `attrs` selectors
      # match against. The default surfaces the node's `type` alongside its
      # decls so `entityKind` works out of the box; node type wins over a
      # same-named decl key because positional kind is authoritative.
      project ? (n: (n.decls or { }) // { inherit (n) type; }),
    }:
    {
      data = id: project (node id);
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
