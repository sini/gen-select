# The seam's admission test: is this value a gen-schema KIND VALUE?
#
# ★ WHAT IT REPLACES, AND WHY THE REPLACEMENT IS NOT COSMETIC. `sel.kind` and
# `adapters.registry.mkContext` used to admit any attrset satisfying `? kind && ? options`, and
# their refusals told the reader the argument had to be "a gen-schema kind value". The predicate
# never checked that: a hand-written `{ kind = "host"; options = { }; }` passed, matched, and was
# INDISTINGUISHABLE from the real thing under `selectorEq`. A provenance-shaped guard over a
# predicate that checks no provenance is the worst of both — a reader believes a property the tree
# already violates. ADR-0034 closes it at the producer: gen-schema mints `__mint.minted` over the
# kind's declared inert surface, through the substrate's one minting authority, and this is the
# read.
#
# FOUR READS, AND THE LAST IS gen-algebra's `hasMark`, NOT `? __mint` ALONE. `__mint` is a TAGGED
# SUM, authored in `gen-algebra/lib/intensional.nix`, whose contract forbids branching on field
# presence and then reading `.minted` raw: on a value carrying no mintable identity `? __mint`
# holds while `minted` is absent, and that read aborts uncatchably rather than refusing. `hasMark`
# is how the MINTED ARM IS SELECTED, read from the library that authors the tag. A presence-only
# `? __mint` would also be measurably no better than the `? options` it replaces — a literal is a
# literal.
#
# ★ WHY THIS IS `algebra.hasMark` AND NOT `algebra.identityOf`. A kind mark is not an identity: a
# kind with any option default carries a non-empty `__sealed`, and `identityOf` answers the
# compared arm for it while the mark is still minted. Admission through `identityOf` would refuse
# every such kind. `identityOf`'s fall-through arm is also `{ unmigrated = v.name; }`, a
# PROGRAM-POINT name a kind value does not carry. The mark readers are the ones a kind is read by.
#
# NOTHING BELOW FORCES THE DIGEST. `hasMark` forces the mark RECORD and stops, which is the same
# reach gen-schema's own guards take — its `mkInstanceRegistry` guard sits at option-declaration
# time and would deadlock if the read went one level further.
{ hasMark }:
v: builtins.isAttrs v && v ? kind && hasMark v
