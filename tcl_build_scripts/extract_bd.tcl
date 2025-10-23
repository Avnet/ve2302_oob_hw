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
if { $argc != 8 } {
	puts "⚠️ Error! extract_bd.tcl requires 7 args:"
	puts "0 - dir of Vivado prj to extract"
	puts "1 - name of Vivado xpr prj to extract (without .xpr)"
	puts "2 - name of Vivado design to extract"
	puts "3 - dir and name of the tcl file to output"
	puts "4 - Name of Vivado prj to embed in output tcl"
	puts "5 - Name of design to embed in output tcl"
	puts "6 - if set \"null\" extracts from existing project, \
			 otherwise should contain path/name of a tcl \
			 file to integrate into this system"
	puts "7 - if not set to null this emits at the top of the \
			 extracted tcl where to look locally for a bdf"
	exit 1
} else {
	set in_project_loc [lindex $argv 0]
	set in_vivado_prj_name [lindex $argv 1]
	set in_vivado_design_name [lindex $argv 2]
	set out_tcl_file [lindex $argv 3]
	set tcl_vivado_prj_name [lindex $argv 4]
	set tcl_design_name [lindex $argv 5]
	set integrate [lindex $argv 6]
	set bdf_loc [lindex $argv 7]
}

if { $integrate == "null" } {
	# open block design and top BD then export it
	open_project "${in_project_loc}/${in_vivado_prj_name}.xpr"
	update_compile_order -fileset sources_1
	set all_bd_files [get_files *.bd -of_objects [get_filesets sources_1]]
	if { [llength $all_bd_files] == 0 } {
		error "⚠️ Error: No Block Design (*.bd) files were found in the project."
	}
	set bd_file [lindex $all_bd_files 0]
	set bd_name [file rootname [file tail "$bd_file"]]
	open_bd_design "$bd_file"
	# Export the board design without any validation
	write_bd_tcl -force "__${tcl_design_name}"
	set input_tcl "__${tcl_design_name}.tcl"
	set out_tmp_tcl "${in_project_loc}/__temp_design.tmp"
} else {
	# If doing a local conversion, in_project_loc will contain the path/name to be converted
	set input_tcl "$integrate"
	set out_tmp_tcl "__temp_design.tmp"
}

# Now override the Vivado defaults
set fin [open "$input_tcl" r]
set fout [open "$out_tmp_tcl" w]

# Force a path to look for local bdf (if needed)
if { "$bdf_loc" != "null" } {
	puts $fout "######################################"
	puts $fout "# Force usage of local bdf over main #"
	puts $fout "######################################"
	puts $fout "set_param board.repoPaths ${bdf_loc}"
}

# Parse through the rest of the file and override default proj/design names
while { [gets $fin line] >= 0 } {
	regsub {create_project\s+(\S+)\s+(\S+)(.*)} $line \
		"create_project $tcl_design_name ${tcl_vivado_prj_name}\\3" line
	if { $line == "variable design_name" } {
		puts $fout $line
		gets $fin line
		regsub {set design_name\s+(\S+)(.*)} $line \
			"set design_name ${tcl_design_name}\\2" line
	}
	puts $fout $line
}

close $fout
close $fin
file rename -force "$out_tmp_tcl" "$out_tcl_file"

# If project, del temp tcl, otherwise assume user wants to keep original
if { $integrate == "null" } { 
	file delete -force "$input_tcl"
}
puts "✅ Block design extracted, Done."
puts "STATUS: extract_bd.tcl completed."
