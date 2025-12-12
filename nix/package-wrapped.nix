{
  lib,
  alaveteli,
  runCommand,

  # Module
  databaseConfig ? "/dev/null",
  themes ? { },
}:
let
  link-themes = lib.pipe themes [
    (lib.filterAttrs (_: v: lib.isDerivation v))
    (lib.attrValues)
    (lib.concatMapStringsSep "\n" (theme:
    # bash
    ''
      cp -R ${theme} $out/lib/themes/${theme.pname}
    ''))
  ];
in
runCommand "alaveteli-wrapped"
  {
    pname = "alaveteli-wrapped";
    inherit (alaveteli) version;

    nativeBuildInputs = alaveteli.nativeBuildInputs;
    buildInputs = alaveteli.buildInputs;
    env = alaveteli.passthru.env;

    rails = alaveteli.passthru.rails;
    rake = alaveteli.passthru.rake;
  }
  ''
    cp -R --no-preserve=mode ${alaveteli} $out
    ${link-themes}

    postgresqlStart

    pushd $out
      cp ${databaseConfig} config/database.yml

      rake ALAVETELI_NIX_BUILD_PHASE=1 assets:precompile
      rake ALAVETELI_NIX_BUILD_PHASE=1 assets:link_non_digest

      rm config/database.yml
    popd

    postgresqlStop

    chmod +x $out/bin/*
  ''
