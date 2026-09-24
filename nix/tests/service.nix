{
  pkgs,
  package,
  module,
}:

let
  unavailableDocker = pkgs.writeShellScriptBin "docker" ''
    printf '%s\n' "$*" >> /tmp/zooid-selected.log
    if [ "$1" = "info" ]; then
      exit 42
    fi
    exit 97
  '';

  availableDocker = pkgs.writeShellScriptBin "docker" ''
    printf '%s\n' "$*" >> /tmp/zooid-selected.log
    case "$1" in
      info)
        exit 0
        ;;
      image)
        if [ "$2" = "inspect" ]; then
          exit 0
        fi
        ;;
      run)
        # The composition test only needs to prove Zooid invoked this exact
        # provider. It does not emulate an ACP process or a container daemon.
        exit 86
        ;;
    esac
    exit 0
  '';

  fallbackDocker = pkgs.writeShellScriptBin "docker" ''
    printf '%s\n' "$*" >> /tmp/zooid-fallback.log
    exit 0
  '';

  zooidYaml =
    port: ''
      runtime: docker
      container:
        image: example.invalid/zooid-test:latest

      transports:
        http:
          type: http
          port: ${toString port}

      agents:
        test:
          workdir: /var/lib/zooid/workspace
          acp:
            preset: claude
          http:
            transport: http
    '';

  commonEnvironment =
    { port, provider }:
    {
      environment.systemPackages = [ pkgs.curl ];

      environment.etc."zooid/zooid.yaml".text = zooidYaml port;

      # Deliberately point PATH at another docker. The Zooid launcher must
      # overwrite this after EnvironmentFile= is loaded.
      environment.etc."zooid/zooid.env".text = ''
        PATH=${fallbackDocker}/bin
        ZOOID_TOKEN=test-token
      '';

      services.zooid = {
        enable = true;
        inherit package;
        runtime = "docker";
        configDirectory = "/etc/zooid";
        containerEngine.package = provider;
        extraPackages = [ fallbackDocker ];
        environmentFiles = [ "/etc/zooid/zooid.env" ];
      };

      system.stateVersion = "26.05";
    };
in
pkgs.testers.runNixOSTest {
  name = "zooid-service";

  nodes = {
    unavailable =
      { lib, ... }:
      {
        imports = [ module ];
      }
      // commonEnvironment {
        port = 8181;
        provider = unavailableDocker;
      }
      // {
        # Make the expected preflight failure stable for inspection.
        systemd.services.zooid.serviceConfig.Restart = lib.mkForce "no";
      };

    available = {
      imports = [ module ];
    }
    // commonEnvironment {
      port = 8180;
      provider = availableDocker;
    };
  };

  testScript = ''
    start_all()

    unavailable.wait_for_unit("multi-user.target")
    unavailable.wait_until_succeeds("systemctl is-failed zooid.service")
    unavailable.succeed("grep -Fxq 'info' /tmp/zooid-selected.log")
    unavailable.succeed("test ! -e /tmp/zooid-fallback.log")
    unavailable.fail("curl --fail --silent --max-time 1 http://127.0.0.1:8181/")
    unavailable.fail("systemctl is-enabled docker.service")
    unavailable.fail("systemctl is-enabled podman.service")
    unavailable.fail("test -S /run/docker.sock")
    unavailable.fail("test -S /run/podman/podman.sock")

    available.wait_for_unit("zooid.service")
    available.wait_for_open_port(8180)
    available.succeed("grep -Fxq 'info' /tmp/zooid-selected.log")
    available.succeed(
        "grep -Fq 'image inspect example.invalid/zooid-test:latest' /tmp/zooid-selected.log"
    )
    available.succeed("test ! -e /tmp/zooid-fallback.log")
    available.succeed(
        "curl -fsS -N --max-time 10 "
        "-H 'Authorization: Bearer test-token' "
        "-H 'Content-Type: application/json' "
        "--data '{\"prompt\":\"probe\"}' "
        "http://127.0.0.1:8180/agents/test/sessions > /tmp/zooid-response"
    )
    available.succeed("grep -Fq 'run --rm -i' /tmp/zooid-selected.log")
    available.succeed("test ! -e /tmp/zooid-fallback.log")
    available.succeed("systemctl is-active --quiet zooid.service")
    available.fail("systemctl is-enabled docker.service")
    available.fail("systemctl is-enabled podman.service")
    available.fail("test -S /run/docker.sock")
    available.fail("test -S /run/podman/podman.sock")
  '';
}
