{
  lib,
  fetchFromGitHub,
  stdenvNoCC,
  callPackage,
  ruby_3_4,
  writeText,
  formats,
  runCommand,
  makeWrapper,
  bundix,
  writableTmpDirAsHomeHook,

  # build-time deps
  cacert,
  postgresql,
  postgresqlTestHook,
  procps,
  breakpointHook,

  # runtime deps
  binutils_nogold, # provides strings to extract text from Excel files
  catdoc,
  elinks,
  git,
  pdftk,
  poppler-utils,
  unrtf,
  unzip,
  wkhtmltopdf,
  wv, # wvText handles doc files

  # config
  customAlaveteliPatches ? [ ],
  dataDir ? "/var/lib/alaveteli", # TODO: use env var?
  secretsFile ? null,
  themes ? [ ],
  theme ? {
    pname = "alavetelitheme";
    meta.homepage = "https://github.com/mysociety/alavetelitheme.git";
    files = null;
    translationFiles = { };
    proTranslationFiles = { };
  },
}:

let
  sslFix = writeText "rubyssl_default_store.rb" ''
    require "openssl"
    s = OpenSSL::X509::Store.new.tap(&:set_default_paths)
    OpenSSL::SSL::SSLContext.send(:remove_const, :DEFAULT_CERT_STORE) rescue nil
    OpenSSL::SSL::SSLContext.const_set(:DEFAULT_CERT_STORE, s.freeze)
  '';

  # TODO: move to service
  settingsFormat = formats.yaml { };
  alaveteliConfig = settingsFormat.generate "general.yml" {
    THEME_URLS = [
      theme.meta.homepage
    ];
  };
  storageConfig = settingsFormat.generate "storage.yml" {
    local = {
      service = "Disk";
      root = "storage/local";
    };
    raw_emails = {
      service = "Disk";
      # can't use Rails.root here, as it would end up in /nix/store
      root = "storage/raw_emails";
    };
    attachments = {
      service = "Disk";
      root = "storage/attachments";
    };
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "alaveteli";
  version = "0.45.3.2";

  src = fetchFromGitHub {
    owner = "mysociety";
    repo = "alaveteli";
    tag = finalAttrs.version;
    hash = "sha256-9KS2+uGUAM4xT715eB+/Df83EB4Qibn2nx03SaZWr4U=";
    fetchSubmodules = true;
    leaveDotGit = true;
    nativeBuildInputs = [
      bundix
      writableTmpDirAsHomeHook
    ];
    postFetch = ''
      pushd $out
        # generate gemset.nix
        bundix
      popd
    '';
  };

  patches = [
    # move xapiandb out of source tree and into dataDir
    # TODO: these patches hardcode /var/lib/alaveteli, but we should really
    # use cfg.dataDir instead. Maybe use substituteInPlace in postPatch?
    ./patches/models_info_request.patch
    ./patches/models_mail_server_log.patch
    ./patches/models_outgoing_message.patch
    ./patches/public_body_controller.patch
    ./patches/conf_env_prod.patch
    ./patches/lib_acts_as_xapian.patch
    ./patches/lib_configuration.patch
    ./patches/lib_mail_handler.patch
    ./patches/routes_rb.patch
    ./patches/theme_loader_rb.patch
    ./patches/themes_rake.patch
  ]
  ++ customAlaveteliPatches;

  postPatch =
    # bash
    ''
      sed -i -e "s|ruby '3.2.[0-9]\+'|ruby '${ruby_3_4.version}'|" Gemfile
      sed -i -e "s|ruby 3.2.[0-9]\+p[0-9]\+|ruby ${ruby_3_4.version}|" Gemfile.lock
      rm public/views_cache
    '';

  nativeBuildInputs = [
    cacert
    postgresql
    postgresqlTestHook
    procps
    writableTmpDirAsHomeHook
    breakpointHook
  ];

  buildInputs = [
    git
    finalAttrs.passthru.rubyEnv
    finalAttrs.passthru.rubyEnv.wrappedRuby
    finalAttrs.passthru.rubyEnv.bundler
  ];

  env = {
    # force production env here, as we don't build the package in development
    RAILS_ENV = "production";

    # redis does not seem to be required to compile assets,
    # but rails expects a database, although it does not seem
    # to actually use it
    DBHOST = "127.0.0.1";
    PGDATABASE = "alaveteli_production";
    PGUSER = "alaveteli";
    postgresqlEnableTCP = 1;
  };

  postgresqlTestUserOptions = "LOGIN SUPERUSER";
  postgresqlTestSetupPost = ''
    export DATABASE_URL="postgresql://$PGUSER@$DBHOST/$PGDATABASE"
  '';

  preBuild = ''
    postgresqlStart

    # Don't attempt to start the database again in the check phase.
    skipHook=postgresqlStart
    preCheckHooks=( "''${preCheckHooks[@]/''$skipHook}" )

    ${
      # copy theme files into the main rails tree before building the package,
      # as they are needed for asset precompilation. Without this, the site
      # builds and runs, but the theme CSS is not applied, for instance.
      lib.optionalString (theme.files != null)
        # bash
        ''
          mkdir -p lib/themes/${theme.pname}/
          cp -R ${theme.files}/* lib/themes/${theme.pname}/
        ''
    }
  '';

  buildPhase =
    # bash
    ''
      runHook preBuild

      # we need to have access to the theme here in config/general.yml, otherwise
      # theme assets can't be found
      cat ${alaveteliConfig} > config/general.yml
      cat ${storageConfig} > config/storage.yml
      echo "BUILDING PKG"
      pwd
      command -v rake
      echo $PATH
      rake ALAVETELI_NIX_BUILD_PHASE=1 assets:precompile
      rake ALAVETELI_NIX_BUILD_PHASE=1 assets:link_non_digest

      rm config/general.yml
      rm config/storage.yml

      # remove some useless files
      rm config/*example

      ps aux | grep redis

      postgresqlStop

      # copy locale translation files
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (locale: f: ''
          mkdir -p locale/${locale}
          cp ${f} locale/${locale}
        '') theme.translationFiles
      )}

      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (locale: f: ''
          mkdir -p locale_alaveteli_pro/${locale}
          cp ${f} locale_alaveteli_pro/${locale}
        '') theme.proTranslationFiles
      )}

      runHook postBuild
    '';

  installPhase = ''
    runHook preInstall

    cp -R . $out
    rm -rf $out/config/database.yml $out/tmp $out/log
    # dataDir will be set in the module, and the package gets overriden there
    ln -s ${dataDir}/config/general.yml $out/config/general.yml
    ln -s ${dataDir}/config/database.yml $out/config/database.yml
    ln -s ${dataDir}/config/storage.yml $out/config/storage.yml
    ln -s ${dataDir}/tmp $out/tmp
    ln -s ${dataDir}/log $out/log

    runHook postInstall
  '';

  passthru = {
    # binaries needed by alaveteli's rails/rake... at runtime
    runtimeDeps = [
      finalAttrs.passthru.rubyEnv.wrappedRuby
      binutils_nogold # provides strings to extract text from Excel files
      catdoc
      elinks
      git
      pdftk
      poppler-utils
      unrtf
      unzip
      wkhtmltopdf
      wv # wvText handles doc files
    ];

    # make rake/rails commands available on the server
    # with the correct gems and dependencies configured
    # Run these with sudo -u alaveteli to allow database connection
    # and access to relevant secrets
    rails =
      runCommand "rails-alaveteli"
        {
          nativeBuildInputs = [ makeWrapper ];
        }
        # bash
        ''
          mkdir -p $out/bin
          makeWrapper ${finalAttrs.passthru.rubyEnv}/bin/rails $out/bin/rails-alaveteli \
              --prefix PATH : ${lib.makeBinPath finalAttrs.passthru.runtimeDeps} \
              --set RAILS_ENV production \
              --set RUBYOPT "-r${sslFix} $RUBYOPT" \
              --chdir '${finalAttrs.finalPackage}' \
              ${
                if secretsFile != null then
                  ''
                    --run "set -a; source ${secretsFile}; set +a"
                  ''
                else
                  ''''
              }
        '';

    rake =
      runCommand "rake-alaveteli"
        {
          nativeBuildInputs = [ makeWrapper ];
        }
        # bash
        ''
          mkdir -p $out/bin
          makeWrapper ${finalAttrs.passthru.rubyEnv}/bin/rake $out/bin/rake-alaveteli \
              --prefix PATH : ${lib.makeBinPath finalAttrs.passthru.runtimeDeps} \
              --set RAILS_ENV production \
              --set RUBYOPT "-r${sslFix} $RUBYOPT" \
              --chdir '${finalAttrs.finalPackage}' \
              ${
                if secretsFile != null then
                  ''
                    --run "set -a; source ${secretsFile}; set +a"
                  ''
                else
                  ''''
              }
        '';

    rubyEnv = callPackage ./bundlerEnv.nix {
      gemdir = finalAttrs.src;
      extraConfigPaths = [ "${./..}/gems" ];
    };
  };

  # TODO: this was to get around a ./result symlink that points to the test runner
  # but why??
  dontCheckForBrokenSymlinks = true;

  meta = {
    description = "Alaveteli, a Freedom of Information request system for your jurisdiction";
    homepage = "https://alaveteli.org";
    license = lib.licenses.agpl3Plus;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    maintainers = with lib.maintainers; [ laurents ];
  };
})
