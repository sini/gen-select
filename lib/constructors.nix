rec {
  star = {
    __sel = "star";
  };

  attrs = a: {
    __sel = "attrs";
    inherit a;
  };

  # Sugar: matches nodes of a given entity kind. Requires a context whose
  # data projection surfaces node type (adapters.scope.mkContext default).
  entityKind = kind: attrs { type = kind; };

  and = selectors: {
    __sel = "and";
    inherit selectors;
  };

  any = selectors: {
    __sel = "any";
    inherit selectors;
  };

  not = selector: {
    __sel = "not";
    inherit selector;
  };

  has = selector: {
    __sel = "has";
    inherit selector;
  };

  within = selector: {
    __sel = "within";
    inherit selector;
  };

  parentMatches = selector: {
    __sel = "parentMatches";
    inherit selector;
  };

  child =
    parentSel: childSel:
    and [
      childSel
      (parentMatches parentSel)
    ];

  descendant =
    ancSel: descSel:
    and [
      descSel
      (within ancSel)
    ];

  when = fn: {
    __sel = "when";
    inherit fn;
  };

  isIdentified =
    selector:
    selector.__sel == "when"
    && builtins.isAttrs selector.fn
    && selector.fn ? name
    && selector.fn ? __functor
    && selector.fn ? closure;

  selectorEq =
    a: b:
    if a.__sel == "when" && b.__sel == "when" then
      let
        isIntensional = v: builtins.isAttrs v && v ? name && v ? __functor && v ? closure;
        # Conservative equality by program point (Palmer §2.3). Inlined from the former
        # gen-algebra.intensionalEq (`a: b: a.name == b.name`) — one trivial line, not
        # worth a library dependency.
        intensionalEq = x: y: x.name == y.name;
      in
      if isIntensional a.fn && isIntensional b.fn then intensionalEq a.fn b.fn else false
    else
      a == b;
}
