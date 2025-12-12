{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    nixpkgsrspamd.url = "github:laurents/nixpkgs/fix-rspamd-config-file";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      devenv,
      ...
    }@inputs:
    # attributes that depend on the system (e.g. packages.x86_64-linux)
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        alaveteli = pkgs.callPackage ./nix/package.nix { };
        devPkgs = pkgs.extend (final: prev: { inherit alaveteli; });
      in
      {
        packages.alaveteli = alaveteli;
        themes = pkgs.callPackage ./nix/themes { };

        devShells =
          (import ./nix/flake/shells.nix { inherit pkgs alaveteli; })
          // (import ./nix/devenv/shells.nix { inherit self inputs devPkgs; });
      }
    )
    # system-independant attributes (e.g. nixosModules)
    // flake-utils.lib.eachDefaultSystemPassThrough (system: {
      nixosModules.devenv-shell-common = import ./nix/devenv/modules/shell-common.nix;
    });
}
