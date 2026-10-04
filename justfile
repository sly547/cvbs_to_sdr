# Copyright (c) 2026 Michael Büchler
# SPDX-License-Identifier: MIT

set shell := ["bash", "-c"]

vivado_path := "/mnt/ssd/tools/Xilinx/2025.2/Vivado/settings64.sh"
core_name := "cvbs_to_sdr"

ip:
    #!/usr/bin/env bash
    echo "creating IP"
    source {{vivado_path}}
    vivado -mode batch -source ../../scripts/core.tcl -tclargs {{core_name}}
