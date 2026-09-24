{
  lib,
  stdenv,
  nodejs_22,
  pnpm_10,
  pnpmConfigHook,
  fetchPnpmDeps,
  makeWrapper,
}:

let
  pnpm = pnpm_10;
  cliPackage = builtins.fromJSON (builtins.readFile ../packages/cli/package.json);
in
stdenv.mkDerivation (finalAttrs: {
  pname = "zooid";
  version = cliPackage.version;

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../package.json
      ../pnpm-lock.yaml
      ../pnpm-workspace.yaml
      ../tsconfig.base.json
      ../packages
    ];
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      ;
    inherit pnpm;
    fetcherVersion = 4;
    hash = "sha256-grnIHEov9/MEyDLZKxoK2UGB0Lxwdb10jMeBkD5suVE=";
  };

  nativeBuildInputs = [
    nodejs_22
    pnpm
    pnpmConfigHook
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild

    pnpm --filter 'zooid...' build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    packageOut="$out/lib/zooid"
    pnpm config set inject-workspace-packages true
    pnpm --filter zooid --prod --ignore-scripts deploy "$packageOut"

    mkdir -p "$out/bin"
    makeWrapper ${lib.getExe nodejs_22} "$out/bin/zooid" \
      --add-flags "$packageOut/dist/bin.js"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    "$out/bin/zooid" --help > help.txt
    grep -q 'zooid' help.txt

    runHook postInstallCheck
  '';

  meta = {
    description = "Chat app for collaborating with AI agents over Matrix and HTTP transports";
    homepage = "https://zooid.dev";
    license = lib.licenses.mit;
    mainProgram = "zooid";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
})
