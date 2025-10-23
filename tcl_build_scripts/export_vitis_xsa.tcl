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
if { $argc != 3 } {
	puts "⚠️ Error! export_vitis_xsa.tcl requires 3 args:"
	puts "0 - Vivado project dir"
	puts "1 - Vivado Design Name"
	puts "2 - Path/name of Vitis XSA" 
	exit 1
} else {
	set project_dir [lindex $argv 0]
	set design_name [lindex $argv 1]
	set xsa_file [lindex $argv 2]
}

# open project
open_project "${project_dir}/${design_name}.xpr"

# Obtain BD path/name
set all_bd_files [get_files *.bd -of_objects [get_filesets sources_1]]
if { [llength $all_bd_files] == 0 } {
	error "⚠️ Error: No Block Design (*.bd) files were found in the project."
}
set bd_file [lindex $all_bd_files 0]
set bd_name [file rootname [file tail "$bd_file"]]

# For vitis, the xsa only needs the generated IP (does not need full-synth or bitstream)
generate_target all [get_files  "$bd_file"]

# Set properties (optional when using -fixed)
write_hw_platform -fixed -force -file "$xsa_file"
validate_hw_platform "$xsa_file"
puts "✅ Created Vitis XSA, Done."
puts "STATUS: export_vitis_xsa.tcl completed."