{
  lib,
  age,
  bash,
  bubblewrap,
  cacert,
  closureInfo,
  coreutils,
  curl,
  diffutils,
  dig,
  fd,
  file,
  findutils,
  gawk,
  gcc,
  git,
  glibcLocales,
  gnugrep,
  gnumake,
  gnused,
  gnutar,
  gzip,
  inetutils,
  jq,
  jujutsu,
  lean4,
  less,
  libreoffice,
  man,
  minisign,
  mkcert,
  nano,
  ncurses,
  nix,
  nodejs,
  openssl,
  pandoc,
  patch,
  perl,
  pi-coding-agent,
  poppler-utils,
  procps,
  proverif,
  python3,
  qpdf,
  ripgrep,
  rocq-core,
  sage,
  tamarin-prover,
  tree,
  unzip,
  util-linux,
  vim,
  which,
  zip,
  wget,
  writeShellApplication,
  writeText,

  agentName ? "pi",
  env ? { },
  packages ? [ ],
  TERM ? "xterm-256color",
  TERMINFO ? "${ncurses}/share/terminfo",

  networkSupport ? true,
  pdfSupport ? true,
  docSupport ? false,
  cryptoSupport ? false,
  proverSupport ? false,
  nodeSupport ? agentName == "pi",
  pythonSupport ? true,
}:
let
  agent =
    if agentName == "pi" then
      {
        package = pi-coding-agent;
        program = "${pi-coding-agent}/bin/pi";
        globals = [
          ".pi"
          ".agents"
        ];
        readonly = [
          ".pi/agent/AGENTS.md"
          ".pi/agent/SYSTEM.md"
          ".pi/agent/APPEND_SYSTEM.md"
        ];
      }
    else
      throw "unsupported agent: ${agentName}";

  agentBinds =
    lib.concatMapStringsSep "\n" (
      path: "  --bind-try \"$HOME/${path}\" /home/agent/${path} \\"
    ) agent.globals
    + "\n"
    + lib.concatMapStringsSep "\n" (
      path: "  --ro-bind-try \"$HOME/${path}\" /home/agent/${path} \\"
    ) agent.readonly;

  apiKeys = [
    "ANTHROPIC_API_KEY"
    "OPENAI_API_KEY"
    "DEEPSEEK_API_KEY"
    "GEMINI_API_KEY"
    "OPENCODE_API_KEY"
    "KIMI_API_KEY"
  ];

  passwd = writeText "etc-passwd" ''
    agent:x:1621:1621:agent:/home/agent:/bin/sh
  '';

  group = writeText "etc-group" ''
    agent:x:1621:
    nobody:x:65534:agent
  '';

  hosts = writeText "etc-hosts" ''
    127.0.0.1 localhost sandbox
    ::1 localhost sandbox
  '';

  resolvConf = writeText "etc-resolv.conf" ''
    nameserver 1.1.1.1
  '';

  nsswitchConf = writeText "etc-nsswitch.conf" ''
    passwd:     files
    group:      files
    initgroups: files
    hosts:      files dns
    protocols:  files
    services:   files
  '';

  envVars =
    lib.concatMapAttrsStringSep "\n" (
      name: value: "  --setenv ${lib.escapeShellArg name} ${lib.escapeShellArg value} \\"
    ) env
    + lib.optionalString (env != { }) "\n"
    + lib.concatMapStringsSep "\n" (var: "  --setenv ${var} \"\${${var}:-}\" \\") apiKeys;

  runtimeInputs = [
    agent.package
    bash
    coreutils
    diffutils
    fd
    file
    findutils
    gawk
    gcc
    git
    glibcLocales
    gnugrep
    gnumake
    gnused
    gnutar
    gzip
    jq
    jujutsu
    less
    man
    nano
    ncurses
    nix
    patch
    perl
    procps
    ripgrep
    tree
    unzip
    util-linux
    vim
    which
    zip
  ]
  ++ lib.optionals networkSupport [
    cacert
    curl
    dig
    inetutils
    wget
  ]
  ++ lib.optionals pdfSupport [
    poppler-utils
    qpdf
  ]
  ++ lib.optionals docSupport [
    libreoffice
    pandoc
  ]
  ++ lib.optionals cryptoSupport [
    age
    minisign
    mkcert
    openssl
    sage
  ]
  ++ lib.optionals proverSupport [
    lean4
    proverif
    rocq-core
    tamarin-prover
  ]
  ++ lib.optional nodeSupport nodejs
  ++ lib.optional pythonSupport (
    python3.withPackages (
      ps:
      with ps;
      [
        matplotlib
        numpy
        pandas
        pillow
        pydantic
        pytest
        scipy
      ]
      ++ lib.optionals networkSupport [
        beautifulsoup4
        lxml
        playwright
        requests
        scapy
      ]
      ++ lib.optionals pdfSupport [
        ocrmypdf
        pdfplumber
        pypdf
        reportlab
      ]
      ++ lib.optionals docSupport [
        lxml
        markitdown
        openpyxl
      ]
      ++ lib.optionals cryptoSupport [
        cryptography
      ]
    )
  )
  ++ packages;

  closure = closureInfo { rootPaths = runtimeInputs; };

  storePaths = lib.filter (line: line != "") (
    lib.splitString "\n" (lib.fileContents "${closure}/store-paths")
  );

  storeBinds = lib.concatMapStringsSep "\n" (path: "  --ro-bind ${path} ${path} \\") storePaths;
in
writeShellApplication {
  inherit runtimeInputs;

  name = "agent";

  text = ''
    WORKDIR_SRC="$(pwd -P)"
    case "$WORKDIR_SRC" in
    / | "$HOME" | "$HOME"/.* | "$HOME"/.*/*)
      echo "agent: error: insecure working directory \"$WORKDIR_SRC\"" >&2
      exit 1
      ;;
    esac

    WORKDIR_DST="/home/agent/$(basename "$WORKDIR_SRC")"

    clear
    echo "agent: info: host working directory is \"$WORKDIR_SRC\"" >&2
    echo
    exec ${bubblewrap}/bin/bwrap \
      --unshare-all \
      --unshare-user \
      --disable-userns \
      ${if networkSupport then "--share-net \\" else "--unshare-net \\"}
      --uid 1621 \
      --gid 1621 \
      --hostname sandbox \
      --proc /proc --dev /dev \
      --perms 1777 --tmpfs /tmp \
      --symlink "${bash}/bin/bash" /bin/sh \
      --ro-bind ${passwd} /etc/passwd \
      --ro-bind ${group} /etc/group \
      --ro-bind ${hosts} /etc/hosts \
      --ro-bind ${resolvConf} /etc/resolv.conf \
      --ro-bind ${nsswitchConf} /etc/nsswitch.conf \
      --ro-bind-try /etc/protocols /etc/protocols \
      --ro-bind-try /etc/services /etc/services \
    ${storeBinds}
      --dir /home/agent \
    ${agentBinds}
      --bind "$WORKDIR_SRC" "$WORKDIR_DST" \
      --die-with-parent \
      --clearenv \
    ${envVars}
      --setenv COLORTERM "''${COLORTERM:-truecolor}" \
      --setenv HOME /home/agent \
      --setenv LANG "''${LANG:-en_US.UTF-8}" \
      --setenv LOCALE_ARCHIVE "${glibcLocales}/lib/locale/locale-archive" \
      --setenv PATH "$PATH" \
      --setenv PS1 "sandbox$ " \
      --setenv SHELL "${bash}/bin/bash" \
      --setenv SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt \
      --setenv TERM ${lib.escapeShellArg TERM} \
      --setenv TERMINFO ${lib.escapeShellArg TERMINFO} \
      --perms 0700 --dir /run/user/1621 \
      --setenv XDG_RUNTIME_DIR /run/user/1621 \
      --chdir "$WORKDIR_DST" \
      -- ${agent.program} "$@"
  '';

  inheritPath = false;
}
