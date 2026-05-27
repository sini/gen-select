{ lib }:
{
  mkContext =
    { node, get }:
    {
      data = id: (node id).decls;
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
