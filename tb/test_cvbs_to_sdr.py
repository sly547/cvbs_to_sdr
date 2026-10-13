# Copyright (c) 2026 Michael Büchler
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_inv(dut):
    """Try accessing the design."""

    clk_in = Clock(dut.clk_in, 10.0, unit='ns')
    clk_out = Clock(dut.clk_out, 2.5, unit='ns')
    clk_in.start()
    clk_out.start()

    dut.rst_out_n.value = 0
    await clk_in.cycles(4)
    dut.rst_out_n.value = 1
    await clk_in.cycles(4)
    dut.cvbs.value = 100
    await clk_in.cycles(2)
    assert dut.cvbs_inv.value.to_signed() == -65, f"{dut.cvbs_inv.value.to_signed() = }"

    dut.cvbs.value = 2039 # Ymax
    await clk_in.cycles(2)
    assert dut.cvbs_inv.value.to_signed() == -1323, f"{dut.cvbs_inv.value.to_signed() = }"
    assert dut.cvbs_out.value.to_signed() == 213, f"{dut.cvbs_out.value.to_signed() = }"
    await clk_in.cycles(20)

def set_sync(dut, vblank, vsync, hblank, hsync):
    dut.vblank.value = vblank
    dut.vsync.value = vsync
    dut.hblank.value = hblank
    dut.hsync.value = hsync

@cocotb.test()
async def test_sync(dut):
    """Try accessing the design."""

    clk_in = Clock(dut.clk_in, 10.0, unit='ns')
    clk_out = Clock(dut.clk_out, 2.5, unit='ns')
    clk_in.start()
    clk_out.start()

    dut.rst_out_n.value = 0
    await clk_in.cycles(4)
    dut.rst_out_n.value = 1
    await clk_in.cycles(4)
    dut.cvbs.value = 2039 # Ymax

    set_sync(dut, 1, 1, 1, 1)
    await clk_in.cycles(1)
    assert dut.data_out.value == dut.sync_lvl.value

    set_sync(dut, 1, 0, 1, 1)
    await clk_in.cycles(1)
    assert dut.data_out.value == dut.sync_lvl.value

    set_sync(dut, 1, 1, 1, 0)
    await clk_in.cycles(1)
    assert dut.data_out.value == dut.sync_lvl.value

    set_sync(dut, 0, 0, 1, 1)
    await clk_in.cycles(1)
    assert dut.data_out.value == dut.sync_lvl.value

    # vblank

    set_sync(dut, 1, 0, 1, 0)
    await clk_in.cycles(1)
    assert dut.data_out.value == dut.blank_lvl.value

    set_sync(dut, 1, 0, 0, 0)
    await clk_in.cycles(1)
    assert dut.data_out.value == dut.blank_lvl.value

    # no vblank

    set_sync(dut, 0, 0, 1, 1)
    await clk_in.cycles(1)
    assert dut.data_out.value == dut.sync_lvl.value

    set_sync(dut, 0, 0, 1, 0)
    await clk_in.cycles(1)
    assert dut.data_out.value == dut.blank_lvl.value

    # image data

    set_sync(dut, 0, 0, 0, 0)
    await clk_in.cycles(1)
    assert dut.cvbs_out.value.to_signed() == 213, f"{dut.cvbs_out.value.to_signed() = }"
