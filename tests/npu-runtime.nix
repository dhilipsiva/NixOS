{ pkgs, yoga }:
let
  p = yoga.pkgs;
in
pkgs.runCommand "npu-runtime-check"
  {
    nativeBuildInputs = [
      p.npu-smoke.python
      pkgs.zstd
    ];
  }
  ''
    export HOME="$TMPDIR"
    export LD_LIBRARY_PATH=${
      pkgs.lib.makeLibraryPath [
        p.intel-npu-driver
        p.intel-npu-compiler
        p.level-zero
      ]
    }
    python3 - <<'PY'
    import ctypes
    import re
    from pathlib import Path
    import openvino as ov
    ctypes.CDLL('${p.intel-npu-driver}/lib/libze_intel_npu.so.1')
    # Use the exact absolute location searched by the driver, not LD_LIBRARY_PATH.
    loader = ctypes.CDLL('${p.intel-npu-driver}/lib/libopenvino_intel_npu_compiler_loader.so')
    ctypes.CDLL('${p.intel-npu-driver}/lib/libopenvino_intel_npu_compiler.so')
    class Version(ctypes.Structure):
        _fields_ = [('major', ctypes.c_uint16), ('minor', ctypes.c_uint16)]
    compiler, profiling = Version(), Version()
    loader.vclGetVersion.argtypes = [ctypes.POINTER(Version), ctypes.POINTER(Version)]
    loader.vclGetVersion.restype = ctypes.c_int
    assert loader.vclGetVersion(ctypes.byref(compiler), ctypes.byref(profiling)) == 0
    header = Path('${p.intel-npu-driver.src}/compiler/include/npu_driver_compiler.h').read_text()
    expected = int(re.search(r'#define VCL_COMPILER_VERSION_MAJOR (\d+)', header)[1])
    assert compiler.major == expected, (compiler.major, expected)
    ctypes.CDLL(str(Path(ov.__file__).parent / 'libs/libopenvino_intel_npu_plugin.so'))
    assert ov.__version__.startswith('${p.openvino-npu.version}')
    print('NPU plugin, driver and compiler load successfully; physical inference remains pending.')
    PY
    # The merged system firmware must select the same release as userspace.
    for name in vpu_40xx_v0.0.bin vpu_40xx_v1.bin; do
      zstd -dc < ${yoga.config.hardware.firmware}/lib/firmware/intel/vpu/$name.zst > actual.bin
      cmp actual.bin ${p.intel-npu-driver.firmware}/lib/firmware/intel/vpu/$name
    done
    # A sandbox without /dev/accel must fail, never silently run on CPU.
    if ${p.npu-smoke}/bin/npu-smoke > smoke.log 2>&1; then
      echo "NPU smoke test unexpectedly succeeded without an NPU" >&2
      exit 1
    fi
    grep -F 'No accessible NPU device' smoke.log
    touch "$out"
  ''
