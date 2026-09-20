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
# FOUR READS, AND THE LAST TWO ARE NOT INTERCHANGEABLE WITH `? __mint` ALONE. `__mint` is a TAGGED
# SUM, authored in `gen-algebra/lib/intensional.nix`, whose comment forbids branching on field
# presence and then reading `.minted` raw: on a value carrying no mintable identity `? __mint`
# holds while `minted` is absent, and that read aborts uncatchably rather than refusing. `? minted`
# is how the MINTED ARM IS SELECTED. A presence-only `? __mint` would also be measurably no better
# than the `? options` it replaces — a literal is a literal.
#
# ★ WHY THIS IS NOT `algebra.identityOf`, given that this library imports that discipline rather
# than vendoring it (see ./default.nix's header). `identityOf` is total over the three regimes of
# an INTENSIONAL VALUE, and its fall-through arm is `{ unmigrated = v.name; }` — a PROGRAM-POINT
# name, which a kind value does not carry and is not defined to. Routing kind admission through it
# would key this seam to an arm defined over a different population, and it would not answer
# `? kind` at all. The tagged-sum DISCIPLINE is what is shared here, not the accessor.
#
# NOTHING BELOW FORCES THE DIGEST. `v.__mint ? minted` forces the mark RECORD and stops, which is
# the same reach gen-schema's own guards take — its `mkInstanceRegistry` guard sits at
# option-declaration time and would deadlock if the read went one level further.
v: builtins.isAttrs v && v ? kind && v ? __mint && v.__mint ? minted
