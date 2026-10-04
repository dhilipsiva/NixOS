{
  lib,
  fetchurl,
  python313Packages,
  autoPatchelfHook,
  stdenv,
  level-zero,
  ocl-icd,
  onetbb,
}:
let
  release = (builtins.fromJSON (builtins.readFile ./releases.json)).openvino-npu;
in
python313Packages.buildPythonPackage {
  pname = "openvino";
  inherit (release) version;
  format = "wheel";
  src = fetchurl { inherit (release) url hash; };
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    stdenv.cc.cc.lib
    level-zero
    ocl-icd
    onetbb
  ];
  dependencies = with python313Packages; [
    numpy
    packaging
  ];
  # Optional model-conversion telemetry is unnecessary for local inference.
  pythonRemoveDeps = [ "openvino-telemetry" ];
  # OpenVINO loads these libraries dynamically.
  runtimeDependencies = [ "${lib.getLib level-zero}/lib/libze_loader.so.1" ];
  pythonImportsCheck = [ "openvino" ];
  postInstall = ''
    test -f $out/${python313Packages.python.sitePackages}/openvino/libs/libopenvino_intel_npu_plugin.so
  '';
  meta = {
    description = "Stable OpenVINO Python runtime with the Intel NPU plugin";
    homepage = "https://github.com/openvinotoolkit/openvino";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
}
