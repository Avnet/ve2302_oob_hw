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
if { $argc != 4 } {
	puts "The script requires 4 args:"
	puts "0 - Vivado project dir"
	puts "1 - Vivado Design Name"
	puts "2 - Num of threads to use"
	puts "3 - Dir for pdi output"
	exit 1
} else {
	set project_dir [lindex $argv 0]
	set design_name [lindex $argv 1]
	set num_threads [lindex $argv 2]
	set pdi_dir [lindex $argv 3]
}

# open block design
open_project "${project_dir}/${design_name}.xpr"

# Obtain BD path/name
set all_bd_files [get_files *.bd -of_objects [get_filesets sources_1]]
if { [llength $all_bd_files] == 0 } {
	error "⚠️ Error: No Block Design (*.bd) files were found in the project."
}
set bd_file [lindex $all_bd_files 0]
set bd_name [file rootname [file tail "$bd_file"]]

# Obtain impl path/name
set current_run_obj [current_run]
if { $current_run_obj ne "" } {
    set run_name [get_property NAME $current_run_obj]
    set run_path [get_property DIRECTORY $current_run_obj]
    puts "Run Name: $run_name"
    puts "Full Path: $run_path"
} else {
    error "⚠️ Error: no run is currently open."
}

set write_image_incomplete [expr {![string equal \
	[get_property STATUS [get_runs "$run_name"]] "write_device_image Complete!"]}]

# Don't re-run if done
if { $write_image_incomplete } {
	open_bd_design "$bd_file"
	reset_runs "$run_name"
	launch_runs "$run_name" -to_step write_device_image -jobs $num_threads
	wait_on_run "$run_name"
}

open_run "$run_name"
write_device_image -force "${pdi_dir}/${design_name}.pdi"
puts "Wrote PDI, Done."
puts "✅ STATUS: write_pdi.tcl completed."