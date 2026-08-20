# Standalone (non-flake) entry. gen-select takes ONE library dependency — gen-algebra, for
# the identity-regime discipline `selectorEq` reads — so this entry is a FUNCTION of that
# argument rather than the lib value itself. Flake consumers should use the `.lib` output,
# which supplies it from the flake input.
#
#   import ./. { algebra = <gen-algebra.lib>; }
import ./lib
