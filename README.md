# Torpico_vhdl

### Authors:
Ryan Sundermeyer (GitHub: @rsunderr, Discord: .kech)

### Outline:
This directory contains the HDL code used for torpico, as well as the verification code using OSVVM.

### Directories:
- OSVVM_Temp_GHDL
    - Contains temporary log files
- VHDL_LIBS
    - Contains vhdl binaries

### Files:
- pwm_gen.vhd
    - Primary module, generats a square wave based on generics and inputs, includes a stop signal
- testCase_nominal.*
    - nominal or best case scenario test case
- testCase_rapid.*
    - changes to inputs made rapidly, during a pulse
- testCase_binary.*
    - using pulse us of 1 or 0 for binary operation
- testCase_random.*
    - stress test that sends random values to input

### Usage:
- use "tclsh" to open tcl cli 
- run "setup_osvvm.tcl" (sources OSVVM script and build libraries if necessary)
- run "build testCase_< case name >.pro" (Runs vhdl test cases and opens gtkwave, redo this each time you want to rerun after editing your chages)
- run "gtkwave waves.ghw" (This will open up your waveform in gtkwave if not already opened)
