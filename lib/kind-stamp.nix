# The seam's second read of a gen-schema kind value: is it the value its schema built?
#
# gen-schema closes each kind value over itself (`__kindSelf`, a function returning the value the
# schema's merge built; den-hoag-1a4f6). A `//` over a kind value copies its mark and its witness
# unchanged, so the copy's witness still returns the original, and the copy is told from the value by
# Nix `==` against its own witness. It mints nothing: it is ADR-0034's sealed limb, the reified value
# compared under `==`. gen-schema's `kindEq` refuses a kind value this answers `false` for, and
# `selectorEq` decides what that door decides, so the predicate is read here too. It is not published,
# for the reason `./kind-mark.nix` is not: the seam's test is this library's own business.
#
# ★ THE SAME DECISION AS gen-schema's `stampOk` (lib/entry-type.nix), and the agreement is pinned by
# `kind-identity.test-selectorEq-agrees-with-kindEq-on-a-swapped-kind`. Where `==` throws, the pair is
# compared through SLOTS: an attrset through one-key `intersectAttrs` slices, a list through singleton
# cells handed out by `map`. Upstream Nix and Determinate force a shared throwing thunk before their
# identity check and Lix does not, so a whole-record `==` alone splits the evaluators on an honest
# kind with a throwing computed field. Two components that both have no WHNF value agree, as the
# kind's mark tags both `undefined`.
#
# A value with no witness is from a gen-schema that does not stamp, whose own `kindEq` does not read
# one; the caller decides what that means (`./default.nix` `selectorKindKey`).
let
  defined = v: (builtins.tryEval (builtins.seq v true)).success;
  cellAgrees =
    ca: cb: va: vb:
    let
      r = builtins.tryEval (ca == cb);
      da = defined va;
      db = defined vb;
    in
    if r.success then
      r.value
    else if da && db then
      descend va vb
    else
      !da && !db;
  descend =
    a: b:
    if builtins.isAttrs a && builtins.isAttrs b then
      let
        names = builtins.attrNames a;
        slice = n: builtins.intersectAttrs { ${n} = null; };
      in
      names == builtins.attrNames b
      && builtins.all (n: cellAgrees (slice n a) (slice n b) a.${n} b.${n}) names
    else if builtins.isList a && builtins.isList b then
      let
        ca = map (v: [ v ]) a;
        cb = map (v: [ v ]) b;
      in
      builtins.length a == builtins.length b
      && builtins.all (
        i:
        cellAgrees (builtins.elemAt ca i) (builtins.elemAt cb i) (builtins.elemAt a i) (builtins.elemAt b i)
      ) (builtins.genList (i: i) (builtins.length a))
    else
      false;
in
k:
builtins.isFunction k.__kindSelf
&& (
  let
    w = k.__kindSelf null;
  in
  cellAgrees w k w k
)
