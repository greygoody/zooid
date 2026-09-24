{
  pkgs,
  package,
  module,
}:

let
  lib = pkgs.lib;
  system = pkgs.stdenv.hostPlatform.system;

  fakeZooid = pkgs.writeShellScriptBin "zooid" ''
    exit 0
  '';

  fakeDocker = pkgs.writeShellScriptBin "docker" ''
    exit 0
  '';

  evalNixOS =
    zooidConfig:
    import "${pkgs.path}/nixos/lib/eval-config.nix" {
      inherit system;
      modules = [
        module
        {
          system.stateVersion = "26.05";
          services.zooid = zooidConfig;
        }
      ];
    };

  baseline = evalNixOS { };

  packageDefault = evalNixOS { };

  packageOverride = evalNixOS {
    package = fakeZooid;
  };

  missingProvider = evalNixOS {
    enable = true;
    package = fakeZooid;
    runtime = "docker";
    configDirectory = "/etc/zooid";
  };

  declaredProvider = evalNixOS {
    enable = true;
    package = fakeZooid;
    runtime = "docker";
    configDirectory = "/etc/zooid";
    containerEngine.package = fakeDocker;
  };

  capabilityAssertion =
    evaluated:
    lib.findFirst (
      item: lib.hasInfix "services.zooid.containerEngine.package" item.message
    ) null evaluated.config.assertions;

  missingProviderAssertion = capabilityAssertion missingProvider;
  declaredProviderAssertion = capabilityAssertion declaredProvider;

  missingProviderToplevel = builtins.tryEval (
    builtins.deepSeq missingProvider.config.system.build.toplevel.drvPath true
  );

  zooidExtraGroups = declaredProvider.config.users.users.zooid.extraGroups or [ ];

  moduleEvaluation =
    assert toString packageDefault.config.services.zooid.package == toString package;
    assert toString packageOverride.config.services.zooid.package == toString fakeZooid;
    assert missingProviderAssertion != null;
    assert missingProviderAssertion.assertion == false;
    assert lib.hasInfix "enable Docker or Podman" missingProviderAssertion.message;
    assert missingProviderToplevel.success == false;
    assert declaredProviderAssertion != null;
    assert declaredProviderAssertion.assertion == true;
    assert declaredProvider.config.virtualisation.docker.enable == false;
    assert declaredProvider.config.virtualisation.docker.rootless.enable == false;
    assert declaredProvider.config.virtualisation.podman.enable == false;
    assert declaredProvider.config.virtualisation.podman.dockerCompat == false;
    assert declaredProvider.config.virtualisation.podman.dockerSocket.enable == false;
    assert !(builtins.hasAttr "docker" declaredProvider.config.systemd.sockets);
    assert !(builtins.hasAttr "podman" declaredProvider.config.systemd.sockets);
    assert !(builtins.hasAttr "docker" declaredProvider.config.systemd.user.services);
    assert !(builtins.hasAttr "podman" declaredProvider.config.systemd.user.sockets);
    assert !(lib.elem "docker" zooidExtraGroups);
    assert !(lib.elem "podman" zooidExtraGroups);
    assert !(declaredProvider.config.systemd.services.zooid.serviceConfig ? SupplementaryGroups);
    assert declaredProvider.config.networking.firewall.allowedTCPPorts
      == baseline.config.networking.firewall.allowedTCPPorts;
    assert declaredProvider.config.networking.firewall.allowedUDPPorts
      == baseline.config.networking.firewall.allowedUDPPorts;
    assert declaredProvider.config.networking.firewall.interfaces
      == baseline.config.networking.firewall.interfaces;
    assert declaredProvider.config.systemd.services.zooid.serviceConfig.StateDirectory == "zooid";
    pkgs.runCommand "zooid-module-evaluation" { } ''
      mkdir "$out"
      printf '%s\n' \
        'flake-qualified module package default: PASS' \
        'explicit package override: PASS' \
        'missing container provider rejection: PASS' \
        'container/rootless services remain disabled: PASS' \
        'container socket compatibility remains disabled: PASS' \
        'container socket units remain absent: PASS' \
        'container groups remain ungranted: PASS' \
        'firewall remains unchanged: PASS' \
        > "$out/result"
    '';
in
{
  package-help = pkgs.runCommand "zooid-package-help" { nativeBuildInputs = [ package ]; } ''
    mkdir "$out"
    zooid --help > "$out/help.txt"
    grep -q 'zooid' "$out/help.txt"
  '';
}
// lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
  module-evaluation = moduleEvaluation;
}
// lib.optionalAttrs (system == "x86_64-linux") {
  service = import ./tests/service.nix {
    inherit pkgs package module;
  };
}
