{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "alavetelitheme";
  version = "0.40.0.0";

  src = fetchFromGitHub {
    owner = "mysociety";
    repo = "alavetelitheme";
    rev = "use-with-alaveteli-${finalAttrs.version}";
    hash = "sha256-yXCMCKwyAXnSzQ2C4NeGvPWb0bVUo5i4nxqWLuBp3qo=";
  };

  installPhase = ''
    runHook preInstall

    cp -R . $out

    runHook postInstall
  '';

  meta = {
    description = "Example theme for alaveteli";
    homepage = "https://github.com/mysociety/alavetelitheme.git";
    license = lib.licenses.mit;
  };
})
