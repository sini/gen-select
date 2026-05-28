{ lib }:
let
  matchOne =
    selector: id: ctx:
    let
      tag = selector.__sel;
    in
    if tag == "star" then
      true

    else if tag == "attrs" then
      let
        a = selector.a;
        data = ctx.data id;
      in
      builtins.all (k: data ? ${k} && data.${k} == a.${k}) (builtins.attrNames a)

    else if tag == "and" then
      builtins.all (s: matchOne s id ctx) selector.selectors

    else if tag == "any" then
      builtins.any (s: matchOne s id ctx) selector.selectors

    else if tag == "not" then
      !(matchOne selector.selector id ctx)

    else if tag == "has" then
      builtins.any (childId: matchOne selector.selector childId ctx) (ctx.children id)

    else if tag == "within" then
      builtins.any (ancId: matchOne selector.selector ancId ctx) (ctx.ancestors id)

    else if tag == "parentMatches" then
      let
        p = ctx.parent id;
      in
      if p == null then false else matchOne selector.selector p ctx

    else if tag == "when" then
      selector.fn id ctx

    else
      throw "gen-select: unknown selector tag '${tag}'";
in
{
  matches = matchOne;
}
