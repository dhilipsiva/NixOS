{
  lib,
  writeShellApplication,
  python313,
  openvino-npu,
  intel-npu-driver,
  intel-npu-compiler,
  level-zero,
}:
let
  python = python313.withPackages (ps: [
    ps.numpy
    openvino-npu
  ]);
in
writeShellApplication {
  name = "npu-smoke";
  text = ''
    export LD_LIBRARY_PATH=${
      lib.makeLibraryPath [
        intel-npu-driver
        intel-npu-compiler
        level-zero
      ]
    }''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    exec ${python}/bin/python3 ${../scripts/npu-smoke.py} "$@"
  '';
  derivationArgs.passthru = { inherit python; };
}
