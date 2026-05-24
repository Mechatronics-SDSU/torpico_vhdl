# setup_osvvm.tcl

source ../OsvvmLibraries/Scripts/StartUp.tcl

if {![file exists ./OsvvmLibraries]} {
    puts "Building OSVVM libraries..."
    build setup_osvvm.pro
} else {
    puts "OSVVM libraries already appear to be built. Skipping build."
}