# Torpico_vhdl

- vhdl torpico code
- use "tclsh" to open tcl cli 
- run "source ../OsvvmLibraries/Scripts/StartUp.tcl" (I currently have this done automatically in ~/.tclshrc)
- run "build setup_osvvm.pro" (This analyzes/builds the osvvm libraries you need, only ever do once during setup)
- run "build testCase_< case name >.pro" (Runs vhdl files, redo this each time you want to rerun after editing your chages)
- run "gtkwave waves.ghw" (This will open up your waveform in gtkwave)
