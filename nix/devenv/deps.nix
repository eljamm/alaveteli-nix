{
  pkgs,
}:
{
  # packages required to run alaveteli, in production
  # and for development
  running = with pkgs; [
    # TODO: remove packages needed only to build gems
    alaveteli.passthru.rubyEnv.wrappedRuby
    (lib.lowPrio alaveteli.passthru.rubyEnv)
    libpqxx
    # node
    nodePackages.yarn
    libsass
    catdoc
    elinks
    # file # libmagic
    ghostscript
    gnuplot
    icu
    imagemagick
    krb5
    libzip
    pdftk
    poppler
    poppler-utils
    tnef
    unrtf
    xapian
    wget
    wv
    # For gem: Nokogiri
    libiconv
    libxml2
    libxslt
    transifex-cli
    # zlib
    # For gem: psych
    libyaml
  ];

  # additional packages only needed for the dev env
  developing = with pkgs; [
    bundix
    figlet # for the text banner in the dev shell
    secretspec
  ];
}
