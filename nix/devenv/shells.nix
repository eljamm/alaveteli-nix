{
  self,
  inputs,
  devenv ? inputs.devenv,
  devPkgs,
}:
{
  # use this one to develop on core alaveteli, without a theme
  default = devenv.lib.mkShell {
    inherit inputs;
    pkgs = devPkgs;
    modules = [
      self.nixosModules.devenv-shell-common
    ];
  };

  # use this env to develop with some custom theme
  # This lives here as creating a dev env from a separate folder than
  # Rails.root is tricky. The theme folder must be linked from, or copied to,
  # ./lib/themes
  # Start it with: nix develop --no-pure-eval .#devWithTheme
  devWithTheme = devenv.lib.mkShell {
    inherit inputs;
    pkgs = devPkgs;
    modules = [
      {
        enterShell = "echo Using theme";
        env = {
          FOOENV = "themeON";
        };
      }
      self.nixosModules.devenv-shell-common
    ];
  };
}
