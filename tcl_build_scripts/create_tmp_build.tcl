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
	puts "⚠️ Error! create_tmp_build.tcl requires 3 args:"
	puts "0 - The path/name of the existing main Vivado tcl file" 
	puts "1 - The path/name of the tmp Vivado build tcl file to create"
	puts "2 - The path/name of the temp build dir"
	exit 1  
} else {
	set main_tcl_filename [lindex $argv 0]
	set tmp_tcl_filename [lindex $argv 1]
	set build_dir [lindex $argv 2]
}

# Open the project main vivado tcl file, parse and override the project dir
set fin [open "$main_tcl_filename" r]
set fout [open "$tmp_tcl_filename" w]
while { [gets $fin line] >= 0 } {
	regsub {^(\s*create_project\s+\S+\s+)\S+} $line "\\1$build_dir" line
	puts $fout $line
}
close $fout
close $fin
puts "✅ A tmp build tcl file has been created, Done."
puts "STATUS: create_tmp_build.tcl completed."