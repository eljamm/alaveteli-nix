{
  lib,
  alaveteli,
  runCommand,

  themes ? { },
}:
let
  link-themes = lib.pipe themes [
    (lib.filterAttrs (_: v: lib.isDerivation v))
    (lib.attrValues)
    (lib.concatMapStringsSep "\n" (theme:
    # bash
    ''
      cp -R ${theme} $out/opt/lib/themes/${theme.pname}
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
  }
  ''
    cp -R --no-preserve=mode ${alaveteli} $out
    ${link-themes}

    postgresqlStart

    pushd $out/opt
      # TODO: cp ''${databaseConfig} config/database.yml
      rake ALAVETELI_NIX_BUILD_PHASE=1 assets:precompile
    popd

    postgresqlStop
  ''
