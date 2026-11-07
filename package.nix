{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  zlib,
}:
let
  release = lib.importJSON ./hashes.json;
  asset =
    release.sources.${stdenv.hostPlatform.system}
      or (throw "huacnlee/cargo has no release asset for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "cargo-huacnlee";
  inherit (release) version;

  src = fetchurl {
    url = "https://github.com/huacnlee/cargo/releases/download/v${release.version}/cargo-${release.version}-${asset.target}.tar.gz";
    inherit (asset) hash;
  };

  sourceRoot = ".";
  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    zlib
    stdenv.cc.cc.lib
  ];
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 cargo "$out/bin/cargo"
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/cargo" --set CARGO_FORK_AUTO_UPDATE 0
  '';

  meta = {
    description = "Cargo fork with shared build artifacts and automatic cache cleanup";
    homepage = "https://huacnlee.github.io/cargo/";
    changelog = "https://github.com/huacnlee/cargo/releases/tag/v${release.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames release.sources;
    mainProgram = "cargo";
  };
}
