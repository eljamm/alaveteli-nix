{
  pkgs,
  alaveteli,
}:
{
  dev = pkgs.mkShell {
    packages = with pkgs; [
      bundix
      bundler
    ];

    shellHook = ''
      # not necessary, but convenient
      for file in Gemfile Gemfile.lock gemset.nix; do
        FILE_PATH="${alaveteli.src}/$file"
        if [[ -e "$FILE_PATH" ]]; then
          rsync --archive --copy-links --chmod=D755,F644 "$FILE_PATH" ./$file
        fi
      done
    '';
  };
}
