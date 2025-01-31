# ------------------------------------------------------------------------------
# RT-SS_fpga_run.tcl
#
# Author(s): Tom Szymkowiak <thomas.szymkowiak@tuni.fi>
# Date     : 03-dec-2023
#
# Description: Main TCL script to drive the creation of the FPGA prototyping
# project for the RT-SS. 
# ------------------------------------------------------------------------------

puts "\n---------------------------------------------------------";
puts "RT-SS_fpga_run.tcl - Starting...";
puts "---------------------------------------------------------\n";

# ------------------------------------------------------------------------------
# Check/set basic variables
# ------------------------------------------------------------------------------

# check tcl directory has been defined
if [info exists ::env(FPGA_TCL_DIR)] {
    set FPGA_TCL_DIR $::env(FPGA_TCL_DIR);
} else {
    puts "ERROR - Variable FPGA_TCL_DIR is not globally defined in Makefile!\n";
    return 1;
}

# check Vivado project name has been defined
if [info exists ::env(PROJECT_NAME)] {
    set PROJECT_NAME $::env(PROJECT_NAME);
} else {
    puts "ERROR - Variable PROJECT_NAME is not globally defined in Makefile!\n";
    return 1;
}

# define common.tcl script
set FPGA_COMMON_SCRIPT ${FPGA_TCL_DIR}/${PROJECT_NAME}_common.tcl;

# read in common and board specific variables 
source ${FPGA_COMMON_SCRIPT};
source ${FPGA_BOARD_CONFIG_SCRIPT};

# define constraints file of format <project_board_constraints.xdc>
set FPGA_CONSTRAINTS ${FPGA_CONSTR_DIR}/${PROJECT_NAME}_${FPGA_BOARD}_constraints.xdc;

# ------------------------------------------------------------------------------
# Create Vivado Project
# ------------------------------------------------------------------------------

create_project ${PROJECT_NAME} . -force -part ${XLNX_PRT_ID};
set_property board_part ${XLNX_BRD_ID} [current_project];

# ------------------------------------------------------------------------------
# Add files and set includes
# ------------------------------------------------------------------------------

source ${FPGA_SOURCE_FILE_SCRIPT}

# set top design for design and testbench
set_property top ${DUT_TOP_MODULE} [current_fileset];
set_property top ${TB_TOP_MODULE}  [current_fileset -simset];

set_property verilog_define ${FPGA_SYNTH_DEFINES} [current_fileset];
set_property verilog_define ${FPGA_SIM_DEFINES}   [current_fileset -simset];

set_property generic ${FPGA_DUT_PARAMS} [current_fileset];
set_property generic ${FPGA_TB_PARAMS}  [current_fileset -simset];

add_files -fileset constrs_1 -norecurse ${FPGA_CONSTRAINTS};

# ------------------------------------------------------------------------------
# Add IPs
# ------------------------------------------------------------------------------

# separate IPs into a list
if {[llength $FPGA_IP_LIST] != 0} {
    set FPGA_IP_LIST [split $FPGA_IP_LIST " "];
}

# add each synthesised IP to the project
foreach {IP} ${FPGA_IP_LIST} {
    puts "Adding ${IP} IP to project...";
    read_ip ${FPGA_IP_BUILD_DIR}/${IP}/${IP}.srcs/sources_1/ip/${IP}/${IP}.xci;
} 

# ------------------------------------------------------------------------------
# Configure Simulation Settings
# ------------------------------------------------------------------------------

set_property target_simulator Questa [current_project]
set_property compxlib.questa_compiled_library_dir /opt/soc/work/tom_szymkowiak/xilinx_libs_2021_2 [current_project]
set_property -name {questa.simulate.runtime} -value {0ns} -objects [get_filesets sim_1]
set_property -name {questa.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]
set_property -name {questa.elaborate.vopt.more_options} -value { -suppress vopt-2732 -suppress vopt-2723 } -objects [get_filesets sim_1]

# ------------------------------------------------------------------------------
# Run Elaboration
# ------------------------------------------------------------------------------

synth_design -rtl -sfcu -name rtl_1;

# ------------------------------------------------------------------------------
# Run Synthesis
# ------------------------------------------------------------------------------

set_msg_config -id {Timing 38-282} -new_severity {ERROR}

# Configure synthesis strategy
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1];
# Use single file compilation unit mode to prevent issues with import pkg::* statements in the codebase
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value -sfcu -objects [get_runs synth_1];

# Launch synthesis
launch_runs synth_1;
wait_on_run synth_1;
open_run synth_1 -name netlist_1;
# prevents need to run synth again
set_property needs_refresh false [get_runs synth_1]; 

# ------------------------------------------------------------------------------
# Run Place and Route (Implementation)
# ------------------------------------------------------------------------------

# Configure implementation strategy
set_property "steps.opt_design.args.directive" "Default" [get_runs impl_1]
set_property "steps.place_design.args.directive" "Default" [get_runs impl_1]
set_property "steps.route_design.args.directive" "Default" [get_runs impl_1]
set_property "steps.phys_opt_design.args.is_enabled" true [get_runs impl_1]
set_property "steps.phys_opt_design.args.directive" "Default" [get_runs impl_1]
set_property "steps.post_route_phys_opt_design.args.is_enabled" true [get_runs impl_1]
set_property "steps.post_route_phys_opt_design.args.directive" "Default" [get_runs impl_1]

# Launch implementation
launch_runs impl_1 -verbose;
wait_on_run impl_1

# ------------------------------------------------------------------------------
# Generate bitstream
# ------------------------------------------------------------------------------

launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
#
open_run impl_1

# ------------------------------------------------------------------------------
# Generate reports
# ------------------------------------------------------------------------------

# ToDo

puts "\n---------------------------------------------------------";
puts "RT-SS_fpga_run.tcl - Complete!";
puts "---------------------------------------------------------\n";

# ------------------------------------------------------------------------------
# End of Script
# ------------------------------------------------------------------------------
