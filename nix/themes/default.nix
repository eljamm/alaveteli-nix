{
  lib,
  pkgs,
}:
lib.makeScope pkgs.newScope (self: {
  alavetelitheme = self.callPackage ./alavetelitheme.nix { };
  whatdotheyknow = self.callPackage ./whatdotheyknow.nix { };
})
