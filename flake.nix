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
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      rec {
        packages.alaveteli = pkgs.callPackage ./nix/package.nix { };
        plugins = pkgs.callPackage ./nix/themes { };
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            bundix
            bundler
          ];

          shellHook = ''
            # not necessary, but convenient
            for file in Gemfile Gemfile.lock gemset.nix; do
              FILE_PATH="${packages.alaveteli.src}/$file"
              if [[ -e "$FILE_PATH" ]]; then
                rsync --archive --copy-links --chmod=D755,F644 "$FILE_PATH" ./$file
              fi
            done
          '';
        };
      }
    );
}
