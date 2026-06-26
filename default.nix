# Standalone (non-flake) entry. gen-select has zero dependencies — builtins only.
# Flake consumers should use the `.lib` output.
{ ... }: import ./lib { }
