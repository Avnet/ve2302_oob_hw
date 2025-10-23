# MIT License
# Copyright (c) 2025 FredKellerman
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Parse cmd line arguments
if { $argc != 5 } {
	puts "⚠️ Error! create_prj.tcl requires 5 args:"
	puts "0 - Name of tcl file to create project"
	puts "1 - Vivado Design Name"
	puts "2 - Which dir to find all user constraint files"
	puts "3 - Dir containing rtl source code to be used"
	puts "4 - Platform properties tcl script path/name"
	exit 1
} else {
	set tcl_name [lindex $argv 0]
	set design_name [lindex $argv 1]
	set constraints_dir [lindex $argv 2]
	set rtl_dir [lindex $argv 3]
	set plat_props [lindex $argv 4]
}

# Create project and obtain BD name and path
source "$tcl_name"
set all_bd_files [get_files *.bd -of_objects [get_filesets sources_1]]
if { [llength $all_bd_files] == 0 } {
	error "⚠️ Error: No Block Design (*.bd) files were found in the project."
}
set bd_file [lindex $all_bd_files 0]
set bd_name [file rootname [file tail "$bd_file"]]

# Add top wrapper
puts "Creating wrapper for: $bd_file"
set wrapper_file_path [make_wrapper -files "$bd_file" -top]
if { [file exists "$wrapper_file_path"] } {
	puts "Successfully generated wrapper at default location: $wrapper_file_path"
	if {[string match "*.v" "$wrapper_file_path"]} {
		puts "Detected language: Verilog"
	} elseif {[string match "*.vhd" "$wrapper_file_path"]} {
		puts "Detected language: VHDL"
	}
} else {
	error "⚠️ Error: 'make_wrapper' failed or did not generate a file. Check Vivado log for errors."
}
add_files -norecurse "$wrapper_file_path"
set_property top "${design_name}_wrapper" [current_fileset]
puts "Wrapper added, top module set."
update_compile_order -fileset sources_1

# Add any .xdc files found in constraints_dir
set xdc_files [glob -nocomplain -directory "$constraints_dir" *.xdc]
if { [llength $xdc_files] > 0 } {
	import_files -fileset constrs_1 -norecurse $xdc_files
	puts "Added xdc: $xdc_files"
}
# Add any RTL files found in rtl_dir
set rtl_files [glob -nocomplain -directory "$rtl_dir" *.vhd *.vhdl *.v *.vh]
if { [llength $rtl_files] > 0 } {
	add_files -norecurse $rtl_files
	puts "Added RTL: $rtl_files"
}

if { "$plat_props" != "null" } {
	update_compile_order -fileset sources_1
	# Defines the following proc
	source "$plat_props"
	set_platform_properties "$design_name"
	puts "✅ Set platform properties from: $plat_props"
}

update_compile_order -fileset sources_1
puts "✅ Project created, compile order updated, Done."
puts "STATUS: create_prj.tcl completed."
