# testCase_nominal.pro
SetVHDLVersion 2008

library work
analyze pwm_gen.vhd
analyze testCase_nominal.vhd

SetSaveWaves

set sim_rc [catch {simulate testCase_nominal} sim_msg]

set matches [glob -nocomplain -types f ./*/reports/work/testCase_nominal.ghw]

if {[llength $matches] > 0} {
    set src_wave [lindex $matches 0]
    set dst_wave [file normalize "./testCase_nominal.ghw"]
    file copy -force $src_wave $dst_wave
    puts "Copied waveform to: $dst_wave"
    exec /opt/homebrew/bin/gtkwave $dst_wave &
} else {
    puts "Waveform file not found."
}

if {$sim_rc} {
    error $sim_msg
}