# Slave Serial Configuration Manager for Virtex-5 FPGA

![Verilog](https://img.shields.io/badge/Language-Verilog_HDL-blue.svg)
![Toolchain](https://img.shields.io/badge/Toolchain-Xilinx_ISE_%2F_ISim-orange.svg)
![Target Hardware](https://img.shields.io/badge/Target-Virtex--5_FPGA-green.svg)

A bare-metal, synthesizable Verilog RTL Bootloader and Configuration Engine designed to autonomously configure a Xilinx Virtex-5 FPGA from a non-volatile 64-Megabit Honeywell MRAM module via the Slave Serial configuration interface.

Developed during a research internship at **Space Applications Centre (SAC), ISRO, Ahmedabad**.

---

## 📌 Project Overview

SRAM-based FPGAs like the Xilinx Virtex-5 lose their bitstream upon power-down and require an external non-volatile memory to reload configuration data upon reboot. This project bridges a custom 64Mb Honeywell MRAM module (HXNV06400) with the Virtex-5 target FPGA, using a custom PMC interface and custom digital logic to handle memory addressing, die decoding, and serialization[cite: 1, 2].

---

## 🚧 Board & Hardware Constraints

1. **Stacked Die Architecture:** The 64Mb Honeywell MRAM contains four stacked 16Mb physical dies.
2. **Single `CE_B` Line Limitation:** The FPGA configuration interface natively provided only a single Chip Enable signal, whereas the MRAM required four distinct active-low enable lines (`CE_B0` to `CE_B3`)[cite: 1, 2].
3. **Missing Hardware Decoder:** The motherboard lacked onboard decoding logic to switch between memory dies.
4. **PMC Hijack Setup:** Signals were routed through a custom 64-pin PMC hijack connector to break out chip enables (`CE_B0`–`CE_B3`), address lines (`A0`–`A22`), and parallel data lines (`D0`–`D7`) directly[cite: 1, 2].

---

## 🏗️ RTL Architecture

The system is implemented across three core Verilog modules:

### 1. MRAM Intake Engine & 2-to-4 Decoder (`mram_interface.v`)
* Evaluates upper address bits (`sys_addr[22:21]`) in real-time to drive `mram_ce_b[3:0]` across 2MB physical boundaries[cite: 1].
* Maps four 16Mb dies into one continuous 8MB linear address space (`23'h0` to `23'h7FFFFF`)[cite: 1].
* Implements backpressure handshaking (`tx_buffer_full`) to freeze address counting if downstream serialization stalls[cite: 1].

### 2. Double-Buffered PISO Serializer (`piso_serializer.v`)
* Converts 8-bit parallel bytes into a 1-bit serial stream (`v5_din`)[cite: 1].
* Features an integrated **shadow buffer** (staging register) that latches incoming bytes in the background while shifting out the current byte MSB-first[cite: 1].
* Guarantees 100% bus utilization with zero dead cycles between byte transitions[cite: 1].

### 3. Executive Boot FSM & Dual-Clock Domain (`v5_bootloader_top.v`)
* Manages initialization, FPGA reset assertion (`v5_prog_b`), and shutdown flags (`mram_eof`)[cite: 1].
* Runs internal logic on a **3 MHz System Clock** while deriving a gated **1.5 MHz Configuration Clock (`v5_cclk`)**[cite: 1].
* Drives serial data on the **falling edge** of `v5_cclk` and samples on the **rising edge**, maximizing setup/hold margins[cite: 1].

---

## 📊 Verification & Hardware Testing

* **Functional Simulation (Xilinx ISim):** Verified sequential die switching (`1110` -> `0111`), FSM transitions, and confirmed that a diagnostic byte-complete signal (`dbg_byte_pulse`) triggered every 8 clock cycles[cite: 1].
* **Hardware Prototyping:** Programmed the synthesized bitstream onto the physical SAC-ISRO FPGA test bench[cite: 1]. Oscilloscope probes on the 64-pin PMC connector verified clean 1.5 MHz clock waveforms and 100% loss-free bitstream delivery to the target device[cite: 1, 2].

---

## 📁 Repository Map

```text
├── rtl/
│   ├── v5_bootloader_top.v   # Top wrapper & FSM coordinator
│   ├── mram_interface.v      # Memory address logic & 2-to-4 decoder
│   └── piso_serializer.v     # Parallel-In-Serial-Out shift register
├── tb/
│   └── tb_v5_bootloader.v    # ISim functional testbench
└── constraints/
    └── v5_bootloader.ucf     # Pin constraints file
