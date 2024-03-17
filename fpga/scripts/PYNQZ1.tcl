# ------------------------------------------------------------------------------
# PYNQZ1.tcl
#
# Author(s): Tom Szymkowiak <thomas.szymkowiak@tuni.fi>
# Date     : 03-dec-2023
#
# Description: TCL script containing FPGA board configuration values
# ------------------------------------------------------------------------------

puts "\n---------------------------------------------------------"
puts "PYNQZ1.tcl - Starting..."
puts "---------------------------------------------------------\n"

# check board files directory path has been defined
if [info exists ::env(BOARD_FILES_DIR)] {
    set BOARD_FILES_DIR $::env(BOARD_FILES_DIR);
} else {
    puts "ERROR - Variable BOARD_FILES_DIR is not globally defined in Makefile!\n";
    return 1;
}

# The Pynq-Z1 is not a default board in all Vivado versions, so board files 
# must be added manually
puts "Board path is: ${BOARD_FILES_DIR}\n"
set_param board.repoPaths ${BOARD_FILES_DIR}

set XLNX_PRT_ID xc7z020clg400-1
set XLNX_BRD_ID www.digilentinc.com:pynq-z1:part0:1.0
set INPUT_OSC_FREQ_MHZ 125.000

puts "Board Configuration Parameters are:"
puts "Board Part: ${XLNX_PRT_ID}"
puts "Board ID  : ${XLNX_BRD_ID}"
puts "Clock Freq: ${INPUT_OSC_FREQ_MHZ}Mhz\n"

puts "\n---------------------------------------------------------"
puts "PYNQZ1.tcl - Complete!"
puts "---------------------------------------------------------\n"

# ------------------------------------------------------------------------------
# End of Script
# ------------------------------------------------------------------------------