# Standalone (non-flake) entry. gen-select has zero dependencies — builtins only.
# Zero deps, so the entry is the lib value itself, not a function.
# Flake consumers should use the `.lib` output.
import ./lib
