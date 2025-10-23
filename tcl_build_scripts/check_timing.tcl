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
	puts "⚠️ Error! check_timing.tcl requires 3 args:"
	puts "0 - set to \"open\" to open project before checking"
	puts "1 - Vivado project dir"
	puts "2 - Vivado Design Name"
	exit 1  
} else {
	set open_it [lindex $argv 0]
	set project_dir [lindex $argv 1]
	set design_name [lindex $argv 2]
}

# Some scripts call this with an open project or it can open the project itself
if { "$open_it" == "open" } {
	open_project "${project_dir}/${design_name}.xpr"
}

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

# Find the newest timing report
set reports_dir [file join "$run_path" ""]
set report_files [glob -nocomplain [file join "$reports_dir" *timing_summary*.rpt]]
set time_file_list [list]
foreach file $report_files {
    set mtime [file mtime "$file"]
    lappend time_file_list [list $mtime "$file"]
}
set sorted_list [lsort -integer -decreasing -index 0 $time_file_list]
if { [llength $sorted_list] > 0 } {
    set latest_entry [lindex $sorted_list 0]
    set latest_report_path [lindex $latest_entry 1]
    set latest_report_name [file tail "$latest_report_path"]
    puts "Latest timing report full path: $latest_report_path"
} else {
    puts "⚠️ No timing summary report files found."
    set latest_report_name ""
}

# Open the timing report text file and search for the status
set fd [open "$latest_report_path" r]
set timing_met 0
while { [gets $fd line] >= 0 } {
	if [string match {All user specified timing constraints are met.} $line]  { 
		set timing_met 1
		break
	}
}
if { $timing_met == 0 } {
	puts "------------------------------------------------------------------------------"
	puts "⚠️ Error: ${design_name} bitstream generation does not meet timing!!!!!!!!"
	puts "------------------------------------------------------------------------------"
	exit 1
}
puts "✅ Timing constraints are met, Done."
puts "STATUS: check_timing.tcl completed."