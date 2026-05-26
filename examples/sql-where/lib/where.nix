{ lib, selectLib }:
let
  sel = selectLib;
  at = builtins.elemAt;
  len = builtins.length;
  trim =
    s:
    let
      m = builtins.match " *(.*[^ ]) *" s;
    in
    if m == null then s else at m 0;

  # Tokenize a WHERE string into a list of tokens
  # Tokens: { type = "str|op|kw|lparen|rparen"; val = "..."; }
  tokenize =
    str:
    let
      go =
        s:
        if s == "" then
          [ ]
        else
          let
            c = builtins.substring 0 1 s;
            rest = builtins.substring 1 (-1) s;
          in
          if c == " " then
            go rest
          else if c == "(" then
            [ { type = "lparen"; val = "("; } ] ++ go rest
          else if c == ")" then
            [ { type = "rparen"; val = ")"; } ] ++ go rest
          else if c == "'" then
            let
              m = builtins.match "'([^']*)'(.*)" s;
            in
            [ { type = "str"; val = at m 0; } ] ++ go (at m 1)
          else if c == "!" then
            let
              m = builtins.match "!=(.*)" s;
            in
            [ { type = "op"; val = "!="; } ] ++ go (at m 0)
          else if c == "=" then
            [ { type = "op"; val = "="; } ] ++ go rest
          else if c == "," then
            [ { type = "comma"; val = ","; } ] ++ go rest
          else
            let
              m = builtins.match "([a-zA-Z_][a-zA-Z0-9_]*)(.*)" s;
              word = at m 0;
              wordRest = at m 1;
              upper = lib.toUpper word;
            in
            if upper == "AND" || upper == "OR" || upper == "NOT" || upper == "IN" then
              [ { type = "kw"; val = upper; } ] ++ go wordRest
            else
              [ { type = "ident"; val = word; } ] ++ go wordRest;
    in
    go str;

  # Recursive descent parser
  # parseOr -> parseAnd -> parseNot -> parseAtom

  parseOr =
    tokens:
    let
      first = parseAnd tokens;
      collectOr =
        acc: toks:
        if len toks > 0 && (at toks 0).type == "kw" && (at toks 0).val == "OR" then
          let
            next = parseAnd (lib.drop 1 toks);
          in
          collectOr (acc ++ [ next.sel ]) next.rest
        else
          { sel = if len acc == 1 then at acc 0 else sel.or acc; rest = toks; };
    in
    collectOr [ first.sel ] first.rest;

  parseAnd =
    tokens:
    let
      first = parseNot tokens;
      collectAnd =
        acc: toks:
        if len toks > 0 && (at toks 0).type == "kw" && (at toks 0).val == "AND" then
          let
            next = parseNot (lib.drop 1 toks);
          in
          collectAnd (acc ++ [ next.sel ]) next.rest
        else
          { sel = if len acc == 1 then at acc 0 else sel.and acc; rest = toks; };
    in
    collectAnd [ first.sel ] first.rest;

  parseNot =
    tokens:
    if len tokens > 0 && (at tokens 0).type == "kw" && (at tokens 0).val == "NOT" then
      let
        inner = parseNot (lib.drop 1 tokens);
      in
      {
        sel = sel.not inner.sel;
        inherit (inner) rest;
      }
    else
      parseAtom tokens;

  parseAtom =
    tokens:
    let
      tok = at tokens 0;
    in
    if tok.type == "lparen" then
      let
        inner = parseOr (lib.drop 1 tokens);
        # skip rparen
        rest = lib.drop 1 inner.rest;
      in
      { inherit (inner) sel; inherit rest; }
    else if tok.type == "ident" then
      let
        key = tok.val;
        remaining = lib.drop 1 tokens;
        nextTok = at remaining 0;
      in
      if nextTok.type == "op" && nextTok.val == "=" then
        let
          valTok = at remaining 1;
          rest = lib.drop 2 remaining;
        in
        {
          sel = sel.attrs { ${key} = valTok.val; };
          inherit rest;
        }
      else if nextTok.type == "op" && nextTok.val == "!=" then
        let
          valTok = at remaining 1;
          rest = lib.drop 2 remaining;
        in
        {
          sel = sel.not (sel.attrs { ${key} = valTok.val; });
          inherit rest;
        }
      else if nextTok.type == "kw" && nextTok.val == "IN" then
        # expect lparen, list of strings, rparen
        let
          afterLparen = lib.drop 2 remaining; # skip IN and lparen
          collectValues =
            acc: toks:
            let t = at toks 0;
            in
            if t.type == "rparen" then
              { vals = acc; rest = lib.drop 1 toks; }
            else if t.type == "str" then
              let
                nextToks = lib.drop 1 toks;
                # skip optional comma
                skipComma =
                  if len nextToks > 0 && (at nextToks 0).type == "comma" then
                    lib.drop 1 nextToks
                  else
                    nextToks;
              in
              collectValues (acc ++ [ t.val ]) skipComma
            else
              collectValues acc (lib.drop 1 toks);
          collected = collectValues [ ] afterLparen;
        in
        {
          sel = sel.or (map (v: sel.attrs { ${key} = v; }) collected.vals);
          inherit (collected) rest;
        }
      else
        throw "gen-select/sql: unexpected token after identifier '${key}'"
    else
      throw "gen-select/sql: unexpected token '${tok.val}'";

  compile =
    str:
    let
      tokens = tokenize (trim str);
      result = parseOr tokens;
    in
    result.sel;
in
{
  inherit compile;
}
