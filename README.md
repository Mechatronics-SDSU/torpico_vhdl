# Torpico_vhdl

## Authors:
Ryan Sundermeyer (GitHub: @rsunderr, Discord: .kech)

## Outline:
This directory contains the HDL code used for torpico, as well as the verification code using OSVVM.

## Directories:
- OSVVM_Temp_GHDL
    - Contains temporary log files
- VHDL_LIBS
    - Contains vhdl binaries

## Usage:
- use "tclsh" to open tcl cli 
- run "setup_osvvm.tcl" (sources OSVVM script and build libraries if necessary)
- run "build testCase_< case name >.pro" (Runs vhdl test cases and opens gtkwave, redo this each time you want to rerun after editing your chages)
- run "gtkwave waves.ghw" (This will open up your waveform in gtkwave if not already opened)
