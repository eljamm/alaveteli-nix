{
  flake-inputs ? import (fetchTarball {
    url = "https://github.com/fricklerhandwerk/flake-inputs/tarball/4.1.0";
    sha256 = "1j57avx2mqjnhrsgq3xl7ih8v7bdhz1kj3min6364f486ys048bm";
  }),
  flake ? flake-inputs.import-flake { src = ./.; },
  inputs ? flake.inputs,
  system ? builtins.currentSystem,
  pkgs ? import inputs.nixpkgs {
    config = { };
    overlays = [ ];
    inherit system;
  },
  lib ? import "${inputs.nixpkgs}/lib",
}:
{
  inherit
    flake
    inputs
    pkgs
    lib
    ;

  alaveteli = pkgs.callPackage ./nix/package.nix { };
}
