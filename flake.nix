{
  description = "gen-select: selector algebra for attributed graph positions";

  # ONE dependency: gen-algebra, for the identity-regime discipline `selectorEq` reads.
  # The zero-inputs claim this replaces was retired deliberately — see `lib/default.nix`
  # for why the vendored copy stopped being worth its price. gen-algebra declares no inputs
  # itself, so a consumer of gen-select gains a leaf and no transitive closure; no
  # nixpkgs.lib enters either way.
  inputs = {
    gen-algebra.url = "github:sini/gen-algebra";
  };

  outputs =
    { gen-algebra, ... }:
    {
      lib = import ./lib { algebra = gen-algebra.lib; };
    };
}
