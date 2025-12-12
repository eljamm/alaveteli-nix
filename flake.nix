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
      in
      rec {
        packages.alaveteli = pkgs.callPackage ./nix/package.nix { };
        themes = pkgs.callPackage ./nix/themes { };

        devShells = {
          dev = pkgs.mkShell {
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

          # use this one to develop on core alaveteli, without a theme
          default = devenv.lib.mkShell {
            inherit inputs;
            pkgs = pkgs.extend (_: _: { inherit (packages) alaveteli; });
            modules = [
              self.nixosModules.shell-common
            ];
          };

          # use this env to develop with some custom theme
          # This lives here as creating a dev env from a separate folder than
          # Rails.root is tricky. The theme folder must be linked from, or copied to,
          # ./lib/themes
          # Start it with: nix develop --no-pure-eval .#devWithTheme
          devWithTheme = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              {
                enterShell = "echo Using theme";
                env = {
                  FOOENV = "themeON";
                };
              }
              self.nixosModules.shell-common
            ];
          };
        };
      }
    )
    # system-independant attributes (e.g. nixosModules)
    // flake-utils.lib.eachDefaultSystemPassThrough (system: {
      nixosModules.shell-common = import ./devenv/shell.nix;
    });
}
