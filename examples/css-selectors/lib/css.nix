{ lib, genSelect }:
let
  sel = genSelect;
  at = builtins.elemAt;
  len = builtins.length;
  sub = builtins.substring;
  splitOn = pat: str: builtins.filter builtins.isString (builtins.split pat str);
  trim =
    s:
    let
      m = builtins.match " *(.*[^ ]) *" s;
    in
    if m == null then s else at m 0;

  # Parse a compound selector (no combinators) into a list of gen-select constructors
  parseCompoundTokens =
    str:
    if str == "" then
      [ ]
    else
      let
        c = sub 0 1 str;
        rest = sub 1 (-1) str;
        parseTok = mkSel: m: [ (mkSel (at m 0)) ] ++ parseCompoundTokens (at m 1);
      in
      if c == "*" then
        [ sel.star ] ++ parseCompoundTokens rest
      else if c == "#" then
        parseTok (name: sel.attrs { inherit name; }) (builtins.match "#([a-zA-Z0-9_/-]+)(.*)" str)
      else if c == "." then
        parseTok (class: sel.attrs { inherit class; }) (builtins.match "\\.([a-zA-Z0-9_/-]+)(.*)" str)
      else if c == "[" then
        let
          attrParts = splitOn "]" rest;
          inner = at attrParts 0;
          after = if len attrParts > 1 then at attrParts 1 else "";
          eqParts = splitOn "=" inner;
        in
        (
          if len eqParts > 1 then
            [ (sel.attrs { ${at eqParts 0} = at eqParts 1; }) ]
          else
            [ (sel.when (id: ctx: (ctx.data id) ? ${inner})) ]
        )
        ++ parseCompoundTokens after
      else if c == ":" then
        let
          m = builtins.match ":([a-z-]+)\\((.*)\\)(.*)" str;
          pseudo = at m 0;
          inner = at m 1;
          after = at m 2;
          innerSel = parse inner;
          result =
            if pseudo == "not" then
              sel.not innerSel
            else if pseudo == "has" then
              sel.has innerSel
            else if pseudo == "within" then
              sel.within innerSel
            else
              throw "gen-select/css: unknown pseudo-class ':${pseudo}'";
        in
        [ result ] ++ parseCompoundTokens after
      else
        let
          m = builtins.match "([a-zA-Z0-9_/-]+)(.*)" str;
        in
        if m != null then [ (sel.attrs { name = at m 0; }) ] ++ parseCompoundTokens (at m 1) else [ ];

  # Combine a list of tokens into a single selector
  combineTokens =
    tokens:
    if len tokens == 0 then
      sel.star
    else if len tokens == 1 then
      builtins.head tokens
    else
      sel.and tokens;

  # Parse a compound selector string into a single selector
  parseCompound = str: combineTokens (parseCompoundTokens str);

  # Parse a full CSS selector with combinators
  parse =
    str:
    let
      orParts = splitOn "," str;
      childParts = splitOn " > " str;
      descParts = splitOn " " str;

      buildChild =
        parts:
        builtins.foldl' (acc: p: sel.child acc (parse (trim p))) (parse (trim (builtins.head parts))) (
          builtins.tail parts
        );

      buildDesc =
        parts:
        builtins.foldl' (acc: p: sel.descendant acc (parse (trim p))) (parse (trim (builtins.head parts))) (
          builtins.tail parts
        );
    in
    if len orParts > 1 then
      sel.any (map (p: parse (trim p)) orParts)
    else if len childParts > 1 then
      buildChild childParts
    else if len descParts > 1 then
      buildDesc descParts
    else
      parseCompound str;
in
{
  inherit parse parseCompound;
}
