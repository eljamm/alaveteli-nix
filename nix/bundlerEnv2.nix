{
  bundlerEnv,
  ruby_3_4,
  defaultGemConfig,
  writeText,
  writeShellScript,

  # gems deps
  file,
  zlib,
  stdenv,
  nodejs,

  gemdir ? ../.,
  gemfile ? "${gemdir}/Gemfile",
  lockfile ? "${gemdir}/Gemfile.lock",
  gemset ? "${gemdir}/gemset.nix",

  extraConfigPaths ? [ ],
}:
bundlerEnv {
  name = "gems-for-alaveteli";

  inherit
    gemdir
    gemfile
    lockfile
    gemset
    extraConfigPaths
    ;

  # ruby versions that fix the openssl bug: 3.3.10, 3.4.8 (not in nixpkgs yet!)
  ruby = ruby_3_4;

  env =
    let
      # src: https://github.com/ruby/openssl/issues/949#issuecomment-3367944960
      sslFix = writeText "rubyssl_default_store.rb" ''
        require "openssl"
        s = OpenSSL::X509::Store.new.tap(&:set_default_paths)
        OpenSSL::SSL::SSLContext.send(:remove_const, :DEFAULT_CERT_STORE) rescue nil
        OpenSSL::SSL::SSLContext.const_set(:DEFAULT_CERT_STORE, s.freeze)
      '';
    in
    "RUBYOPT='-r${sslFix} $RUBYOPT'";

  gemConfig = defaultGemConfig // {
    mahoro = attrs: { nativeBuildInputs = [ file ]; };
    xapian-full-alaveteli = attrs: { nativeBuildInputs = [ zlib ]; };
    libv8-node =
      attrs:
      let
        noopScript = writeShellScript "noop" "exit 0";
        linkFiles = writeShellScript "link-files" ''
          cd ../..

          mkdir -p vendor/v8/${stdenv.hostPlatform.system}/libv8/obj/
          ln -s "${nodejs.libv8}/lib/libv8.a" vendor/v8/${stdenv.hostPlatform.system}/libv8/obj/libv8_monolith.a

          ln -s ${nodejs.libv8}/include vendor/v8/include

          mkdir -p ext/libv8-node
          echo '--- !ruby/object:Libv8::Node::Location::Vendor {}' >ext/libv8-node/.location.yml
        '';
      in
      {
        dontBuild = false;
        postPatch = ''
          cp ${noopScript} libexec/build-libv8
          cp ${noopScript} libexec/build-monolith
          cp ${noopScript} libexec/download-node
          cp ${noopScript} libexec/extract-node
          cp ${linkFiles} libexec/inject-libv8
        '';
      };

    statistics2 = attrs: {
      buildFlags = [ "--with-cflags=-Wno-error=implicit-int" ];
    };
    syck = attrs: {
      # buildFlags = [ "--with-cflags=-Wincompatible-pointer-types" ];
      env.NIX_CFLAGS_COMPILE = toString [
        "-Wno-error=incompatible-pointer-types"
      ];
    };
  };
}
