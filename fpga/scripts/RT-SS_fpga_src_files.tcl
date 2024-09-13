# ------------------------------------------------------------------------------
# RT-SS_fpga_src_files.tcl
#
# Author(s): Tom Szymkowiak <thomas.szymkowiak@tuni.fi>
#            Antti Nurmi <antti.nurmi@tuni.fi>
# Date     : 03-dec-2023
#
# Description: Source file list for the FPGA prototype of the RT-SS. Adds source
# files/packages to project and sets the project include directories
#
# Ascii art headers generated using https://textkool.com/en/ascii-art-generator
# (style: ANSI Shadow)
# ------------------------------------------------------------------------------

  # read_hdl -f doesn't allow comments, also some files skipped
  proc read_filelist {file {skip_files ""}} {
      set ret {}
      set path [join [lrange [split $file /] 0 end-1] /]
      set fp [open $file r]
      while {[gets $fp line]>=0} {
          set line [string trim $line]
          if {[string index $line 0]=="#"} {continue}
          if {![string length $line]} {continue}
          if {[lindex [split $line /] end] ni $skip_files} {
              lappend ret $path/$line
          }
      }
      return $ret
  }

# Clear the console output
puts "\n---------------------------------------------------------";
puts "RT-SS_fpga_src_files.tcl - Starting...";
puts "---------------------------------------------------------\n";

# ██╗███╗   ██╗ ██████╗██╗     ██╗   ██╗██████╗ ███████╗███████╗
# ██║████╗  ██║██╔════╝██║     ██║   ██║██╔══██╗██╔════╝██╔════╝
# ██║██╔██╗ ██║██║     ██║     ██║   ██║██║  ██║█████╗  ███████╗
# ██║██║╚██╗██║██║     ██║     ██║   ██║██║  ██║██╔══╝  ╚════██║
# ██║██║ ╚████║╚██████╗███████╗╚██████╔╝██████╔╝███████╗███████║
# ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝ ╚═════╝ ╚═════╝ ╚══════╝╚══════╝

set RT_SS_INCLUDE_PATHS " \
  ${RTIBEX_DIR}/vendor/lowrisc_ip/ip/prim/rtl \
  ${RTIBEX_DIR}/vendor/lowrisc_ip/dv/sv/dv_utils \
  ${REGIF_DIR}/include \
  ${OBI_DIR}/include \
  ${APB_DIR}/include \
  ${AXI_DIR}/include \
  ${COMMON_CELLS_DIR}/include \
";

set_property include_dirs ${RT_SS_INCLUDE_PATHS} [current_fileset];
set_property include_dirs ${RT_SS_INCLUDE_PATHS} [current_fileset -simset];

# Read the generated filelist
set SRC_FILES [read_filelist ${REPO_DIR}/fpga/build/fpga_gen.list]
add_files -norecurse -scan_for_includes ${SRC_FILES};


puts "\n---------------------------------------------------------";
puts "RT-SS_fpga_src_files.tcl - Complete!";
puts "---------------------------------------------------------\n";

# ------------------------------------------------------------------------------
# End of Script
# ------------------------------------------------------------------------------
