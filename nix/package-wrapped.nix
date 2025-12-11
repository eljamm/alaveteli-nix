{
  lib,
  alaveteli,
  symlinkJoin,
  themes,
}:
let
  link-themes = lib.pipe themes [
    (lib.filterAttrs (_: v: lib.isDerivation v))
    (lib.attrValues)
    (lib.concatMapStringsSep "\n" (theme:
    # bash
    ''
      ln -s ${theme} $out/opt/lib/themes/${theme.pname}
    ''))
  ];
in
symlinkJoin {
  name = "alaveteli-wrapped";
  paths = [
    alaveteli
  ];

  postBuild = ''
    ${link-themes}
  '';
}
