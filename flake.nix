{
  description = "gen-select: selector algebra for attributed graph positions";

  # Zero dependencies — gen-select is builtins-only (intensionalEq inlined; no
  # nixpkgs.lib, no gen-algebra). The flake therefore declares no inputs, so consumers
  # gain no transitive dependency.
  outputs =
    { ... }:
    {
      lib = import ./lib { };
    };
}
