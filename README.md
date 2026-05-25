# Torpico_vhdl
### Date Created:
5/22/2026

### Authors:
Ryan Sundermeyer (GitHub: @rsunderr, Discord: @.kech)

### Outline:
This directory contains the HDL source code used for torpico, as well as the verification code using OSVVM.
The module in pwm_gen.vhd is intended to be packaged into a custom AXI Lite IP core in Vivado when complete.

### Directories:
- OSVVM_Temp_GHDL
    - Contains temporary log files.
- VHDL_LIBS
    - Contains vhdl binaries.

### Files:
- pwm_gen.vhd
    - Primary module, generats a square wave based on generics and inputs, includes a stop signal.
- testCase_nominal*
    - Nominal or best case scenario test case, sends a few different pulse widths.
- testCase_rapid*
    - Changes to inputs made rapidly, during a pulse.
- testCase_binary*
    - Using pulse us of 1 or 0 for binary operation.
- testCase_random*
    - Stress test that sends random values to input.

### Usage:
- use "tclsh" to open tcl cli 
- run "setup_osvvm.tcl" (sources OSVVM script and build libraries if necessary)
- run "build testCase_< case name >.pro" (Runs vhdl test cases and opens gtkwave, redo this each time you want to rerun after editing your chages)
- run "gtkwave waves.ghw" (This will open up your waveform in gtkwave if not already opened)
