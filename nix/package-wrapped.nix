{
  lib,
  alaveteli,
  symlinkJoin,

  formats,

  themes ? { },
}:
let
  settingsFormat = formats.yaml { };

  link-themes = lib.pipe themes [
    (lib.filterAttrs (_: v: lib.isDerivation v))
    (lib.attrValues)
    (lib.concatMapStringsSep "\n" (theme:
    # bash
    ''
      cp -R ${theme} $out/opt/lib/themes/${theme.pname}
    ''))
  ];

  # TODO: get from module
  filterNull = lib.filterAttrs (_: v: v != null);
  railsMaxThreads = 3;
  databaseConfig = settingsFormat.generate "database.yml" {
    production = lib.mapAttrs (_: v: lib.mkDefault v) (filterNull {
      adapter = "postgresql";
      database = "alaveteli";
      encoding = "utf8";
      host = "/run/postgresql";
      password = "<%= begin IO.read('${"/run/keys/alaveteli-dbpassword"}') rescue '' end %>";
      pool = railsMaxThreads + 2;
      port = null;
      template = "template_utf8";
      timeout = 5000;
      username = "foi";
    });
  };
in
symlinkJoin {
  name = "alaveteli-wrapped";

  paths = [
    alaveteli
  ];

  nativeBuildInputs = alaveteli.nativeBuildInputs;
  buildInputs = alaveteli.buildInputs;
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

  postBuild = ''
    ${link-themes}

    postgresqlStart

    pushd $out/opt
      cp ${databaseConfig} config/database.yml

      rake ALAVETELI_NIX_BUILD_PHASE=1 assets:precompile
    popd

    postgresqlStop
  '';
}
