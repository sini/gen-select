# gen-program bridge. A selector's boolean skeleton (`star`, `and`, `any`, `not`) becomes the
# disjunction of rule bodies gen-program's `declaration` takes as `pos`/`neg`; every other selector
# is a leaf, and its atom is the string the caller's `atomOf` names (gen-program mints no atom, and
# neither does this). Like the other adapters it imports nothing it bridges: only plain data
# crosses. Negation is pushed to the leaves by De Morgan, and conjunction distributes over
# disjunction, both of which hold in Kleene's three-valued logic, so no literal set is simplified
# away: `a ∧ ¬a` is UNDEFINED at an undefined `a`, not false.
#
# The body count is the selector's DNF size, exponential in the worst case. A caller wanting it
# linear compiles a compound sub-selector to a head it declares and names that head as a leaf.
_: {
  bodies =
    atomOf: selector:
    let
      top = [
        {
          pos = [ ];
          neg = [ ];
        }
      ];
      cross =
        xs: ys:
        builtins.concatMap (
          x:
          map (y: {
            pos = x.pos ++ y.pos;
            neg = x.neg ++ y.neg;
          }) ys
        ) xs;
      atom =
        s:
        let
          a = atomOf s;
        in
        if builtins.isString a then
          a
        else
          throw "gen-select.adapters.program.bodies: atomOf named a `${s.__sel}` selector with a ${builtins.typeOf a}; an atom is a string the caller names";
      # `pol` is the leaf's polarity under the `not`s above it.
      go =
        pol: s:
        let
          tag =
            if builtins.isAttrs s && s ? __sel then
              s.__sel
            else
              throw "gen-select.adapters.program.bodies: got ${builtins.typeOf s}${
                if builtins.isAttrs s then " with no `__sel`" else ""
              }, expected a selector (a record built by gen-select's constructors)";
        in
        if tag == "star" then
          (if pol then top else [ ])
        else if tag == "not" then
          go (!pol) s.selector
        # Under an odd number of `not`s, `and` is a disjunction and `any` a conjunction (De Morgan).
        else if tag == "and" || tag == "any" then
          if (tag == "and") == pol then
            builtins.foldl' (acc: x: cross acc (go pol x)) top s.selectors
          else
            builtins.concatMap (go pol) s.selectors
        else if pol then
          [
            {
              pos = [ (atom s) ];
              neg = [ ];
            }
          ]
        else
          [
            {
              pos = [ ];
              neg = [ (atom s) ];
            }
          ];
    in
    go true selector;
}
