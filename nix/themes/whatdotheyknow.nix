{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "whatdotheyknow-theme";
  version = "0.40.0.0";

  src = fetchFromGitHub {
    owner = "mysociety";
    repo = "whatdotheyknow-theme";
    rev = "use-with-alaveteli-${finalAttrs.version}";
    hash = "sha256-NCaMtw8XANQscexm1gxaBVKY8gVYOKCE8fvhqmbbKQA=";
  };

  installPhase = ''
    runHook preInstall

    cp -R . $out

    runHook postInstall
  '';

  meta = {
    description = "Alaveteli theme for WhatDoTheyKnow (UK)";
    homepage = "https://github.com/mysociety/whatdotheyknow-theme";
    license = lib.licenses.mit;
  };
})
