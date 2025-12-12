{
  lib,
  pkgs,
  ...
}:
let
  dbUser = "postgres";
  dbHost = "localhost";
  dbPort = 54321;
  railsPort = "3030"; # to avoid conflict with commonly used 3000
  toYAML = pkgs.lib.generators.toYAML { };

  rails_db_conf = {
    # this config must be overridden in the theme
    development = {
      adapter = "postgresql";
      template = "template_utf8";
      host = dbHost;
      port = dbPort;
      database = "alaveteli_development";
      username = dbUser;
      password = "changeme";
    };
  };
  rails_db_conf_file = pkgs.writeText "database.yml" (toYAML rails_db_conf);
  # ideally, this would load general.yml-example and override its contents
  # with whatever is passed below
  alaveteli_config_general = pkgs.writeText "general.yml" (toYAML {
    OVERRIDE_ALL_PUBLIC_BODY_REQUEST_EMAILS = "publicbody@localhost";
    # THEME_URLS = [ "https://github.com/mysociety/alavetelitheme.git" ];
    THEME_URLS = [
      "https://gitlab.com/madada-team/dada-core.git"
    ];
  });

  deps = import ./deps.nix { inherit pkgs; };
in
{
  packages = deps.running ++ deps.developing;

  enterShell = ''
    export GIT_DIR=$DEVENV_ROOT/.git
    export GIT_WORK_TREE=$DEVENV_ROOT
    git submodule update --init
    # TODO: make sure we use local file storage by default in dev env
    cp config/storage.yml-example config/storage.yml
    rm -f config/general.yml
    ln -s "${alaveteli_config_general}" config/general.yml
    # use the madada config file
    # ln -s ../../dada-core/config/general_dada.yml config/general.yml
    rm -f config/database.yml
    ln -s "${rails_db_conf_file}" config/database.yml
    #
    # The env is now ready
    #
    figlet -f roman -w 90 Alaveteli
    echo "Alaveteli core dev env ready"
    echo "The services you need (postgres, redis, rails server...) can be started with 'devenv up'"
    echo "(keep them running in a separate terminal)"
    echo "once devenv up is ready, alaveteli will be running at http://localhost:${railsPort}/"
    echo "useful commands:"
    echo "rails c (no path, just this!)"
    echo "Outgoing emails are here: http://localhost:8025"

    # Secrets
    secretspec check | awk '/✓ / {print $2}' | xargs -I {} echo "echo export {}=\''${}" > .env
    eval $(secretspec run -- bash ./.env)
  '';

  # this is required to build the pg gem on linux
  # TODO: can we move this to gemConfig instead? we don't need
  # this env var once the gem is built
  env = {
    LD_LIBRARY_PATH = lib.makeLibraryPath [
      pkgs.krb5
      pkgs.openldap
    ];
  };

  processes = {
    # run migrations once postgres is started
    migrate = {
      exec = "rails db:migrate && rails db:seed";
      process-compose.depends_on.postgres.condition = "process_healthy";
    };
    init_xapian = {
      exec = ''
        cd $DEVENV_ROOT
        echo "initing xapian (todo, needs to be run in the alaveteli root folder)"
        # trap 'kill -KILL $(jobs -p); wait; exit 0;' SIGTERM
        # TODO: patch task code to allow configuring the db path outside
        # of rails root dir
        # RAILS_ENV=development rake xapian:create_index
        # wait
      '';
      process-compose.depends_on.migrate.condition = "process_completed_successfully";
    };
    # start the dev web server after migrations
    web = {
      exec = "rails server -p ${railsPort}";
      process-compose.depends_on.init_xapian.condition = "process_completed_successfully";
    };
  };

  scripts.db = {
    description = "Open the database in psql";
    exec = ''
      psql -U ${dbUser} -h ${dbHost} -p ${toString dbPort} ${rails_db_conf.development.database}
    '';
    packages = [ pkgs.postgresql_16 ];
  };

  services.postgres = {
    enable = true;
    package = pkgs.postgresql_16;
    initialDatabases = [
      {
        name = "alaveteli_test";
        user = dbUser;
      }
      {
        name = "alaveteli_development";
        user = dbUser;
      }
      {
        name = "alaveteli_production";
        user = dbUser;
      }
    ];
    initialScript = "CREATE ROLE postgres SUPERUSER; ALTER ROLE postgres WITH LOGIN;";
    listen_addresses = dbHost;
    port = dbPort;
    extensions = extensions: [ ];
  };
  # alaveteli knows to send email to port 1025 in dev
  # which is the default for mailpit
  services.mailpit = {
    enable = true;
  };
  services.redis = {
    enable = true;
  };
}
