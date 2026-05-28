{ lib }:
{
  mkContext =
    {
      nodes,
      data,
      parent,
    }:
    {
      inherit data parent;
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
