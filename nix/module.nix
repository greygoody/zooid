{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.zooid;
  isContainerRuntime = cfg.runtime == "docker" || cfg.runtime == "podman";
  containerEnginePackage = cfg.containerEngine.package;
  runtimeArgument = lib.optionalString (cfg.runtime != null) "--runtime ${cfg.runtime}";
  servicePackages =
    lib.optionals (isContainerRuntime && containerEnginePackage != null) [ containerEnginePackage ]
    ++ cfg.extraPackages;
  servicePath = lib.makeBinPath servicePackages;
  enginePreflight = lib.optionalString (
    isContainerRuntime && containerEnginePackage != null
  ) ''
    if ! ${cfg.runtime} info >/dev/null; then
      echo "Zooid container provider is unavailable: ${cfg.runtime}" >&2
      exit 1
    fi
  '';
  serviceLauncher = pkgs.writeShellScript "zooid-service" ''
    # EnvironmentFile= is loaded by systemd before this launcher. Reset PATH
    # here so it cannot replace the provider selected and validated by Nix.
    export PATH=${lib.escapeShellArg servicePath}

    ${enginePreflight}

    exec ${cfg.package}/bin/zooid start --data /var/lib/zooid ${runtimeArgument}
  '';
in
{
  options.services.zooid = {
    enable = lib.mkEnableOption "Zooid daemon";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./nix/package.nix { }";
      description = "Zooid package to run.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "zooid";
      description = "User account under which Zooid runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "zooid";
      description = "Group account under which Zooid runs.";
    };

    configDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/etc/zooid";
      description = ''
        Directory from which Zooid discovers zooid.yaml and resolves relative
        configuration paths. The module does not create, parse, or mutate the
        application configuration.
      '';
    };

    runtime = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [
        "local"
        "docker"
        "podman"
      ]);
      default = null;
      example = "docker";
      description = ''
        Explicit Zooid runtime passed to `zooid start`. This is required when
        the module is enabled so host capability requirements are visible in
        NixOS configuration instead of being inferred from an opaque YAML file.
      '';
    };

    containerEngine.package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      example = lib.literalExpression "pkgs.docker-client";
      description = ''
        Package providing bin/docker or bin/podman for the selected container
        runtime. Supplying a client package does not enable a daemon, create a
        socket, or grant the Zooid user access to one. Zooid validates this
        provider with `docker info` or `podman info` and executes the same
        provider by giving it first priority on the service PATH.
      '';
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/run/credentials/zooid.env" ];
      description = ''
        systemd EnvironmentFile paths supplied to Zooid. Provision credential
        files separately; do not place secrets in the Nix store. Provider
        connection variables such as DOCKER_HOST may also be supplied here,
        but PATH is controlled by the module.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.git ]";
      description = ''
        Additional explicitly supplied host executables placed on Zooid's PATH.
        For container runtimes the selected container provider always has first
        priority. For runtime = "local", these packages are the service's
        executable PATH. This option does not enable host services or grant
        additional authority.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.runtime != null;
        message = ''
          services.zooid.runtime must be set explicitly to "local", "docker",
          or "podman". The module does not infer host capability requirements
          from zooid.yaml.
        '';
      }
      {
        assertion = !isContainerRuntime || containerEnginePackage != null;
        message = ''
          services.zooid.runtime = "${toString cfg.runtime}" requires
          services.zooid.containerEngine.package. The Zooid module will not
          enable Docker or Podman, create a container socket, or grant socket
          access implicitly.
        '';
      }
    ];

    users.groups.${cfg.group} = lib.mkIf (cfg.group == "zooid") { };

    users.users.${cfg.user} = lib.mkIf (cfg.user == "zooid") {
      isSystemUser = true;
      group = cfg.group;
      home = "/var/lib/zooid";
    };

    systemd.services.zooid = {
      description = "Zooid daemon";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.configDirectory;
        StateDirectory = "zooid";
        StateDirectoryMode = "0750";
        EnvironmentFile = cfg.environmentFiles;
        ExecStart = serviceLauncher;
        Restart = "on-failure";
        RestartSec = "5s";
        UMask = "0077";
      };
    };
  };
}
