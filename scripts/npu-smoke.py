#!/usr/bin/env python3
"""Compile and run a tiny local graph on Intel NPU, never AUTO/HETERO/CPU."""
import os
from pathlib import Path

import numpy as np
import openvino as ov
from openvino import opset13 as ops


def main():
    if os.geteuid() == 0:
        raise SystemExit('Run npu-smoke as your normal user to verify non-root device access.')
    devices = list(Path('/dev/accel').glob('accel*'))
    if not any(os.access(device, os.R_OK | os.W_OK) for device in devices):
        raise SystemExit('No accessible NPU device. Check intel_vpu, firmware and render-group membership.')
    core = ov.Core()
    if not any(device.split('.')[0] == 'NPU' for device in core.available_devices):
        raise SystemExit('OpenVINO cannot find NPU. Check the Level Zero driver and compiler paths.')
    inputs = ops.parameter([1, 16], np.float32, name='input')
    weights = ops.constant(np.eye(16, dtype=np.float32))
    result = ops.relu(ops.matmul(inputs, weights, False, False))
    model = ov.Model([result], [inputs], 'yoga-npu-smoke')
    # Select the compiler distributed with the pinned driver explicitly. The
    # compiler consumes IR; its private runtime need not match the Python wheel.
    compiled = core.compile_model(model, 'NPU', {'NPU_COMPILER_TYPE': 'DRIVER'})
    execution = compiled.get_property('EXECUTION_DEVICES')
    # OpenVINO returns a plain string for a single device and a list otherwise.
    devices = [execution] if isinstance(execution, str) else list(execution)
    if not devices or any(str(device).split('.')[0] != 'NPU' for device in devices):
        raise SystemExit(f'Unexpected execution device: {execution}')
    data = np.arange(-8, 8, dtype=np.float32).reshape(1, 16)
    actual = compiled([data])[compiled.output(0)]
    np.testing.assert_allclose(actual, np.maximum(data, 0), rtol=1e-3, atol=1e-3)
    print(f'NPU inference passed: {core.get_property("NPU", "FULL_DEVICE_NAME")}; '
          f'execution={devices}; OpenVINO={ov.__version__}')
    # Exiting releases the graph/device. Runtime suspend is a separate physical check.


if __name__ == '__main__':
    main()
