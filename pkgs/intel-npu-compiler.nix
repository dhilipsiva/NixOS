# Intel's compiler from the same stable release as the userspace driver/firmware.
# The compiler includes its own matching OpenVINO runtime, independent of the
# Python frontend. No CMake downloads or runtime pip installation are permitted.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  onetbb,
  zstd,
  zlib,
}:
let
  release = (builtins.fromJSON (builtins.readFile ./releases.json)).intel-npu-compiler;
in
stdenv.mkDerivation {
  pname = "intel-npu-compiler";
  inherit (release) version;
  src = fetchurl { inherit (release) url hash; };
  sourceRoot = ".";
  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    onetbb
    zstd
    zlib
  ];
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    dpkg-deb -x intel-driver-compiler-npu_*.deb compiler
    mkdir -p $out/lib
    cp -a compiler/usr/lib/x86_64-linux-gnu/. $out/lib/
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    test -e $out/lib/libopenvino_intel_npu_compiler.so
    test -e $out/lib/libopenvino_intel_npu_compiler_loader.so
  '';
  meta = {
    description = "Intel NPU compiler paired with the stable Linux NPU driver";
    homepage = "https://github.com/intel/linux-npu-driver";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
}
