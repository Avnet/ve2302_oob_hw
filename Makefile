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

# NOTE: Do not use spaces or punctuation for any the paths or names!

##############################################
# You will likely want to change per project #
##############################################
DESIGN_NAME ?= ve2302_oob

####################################################
# You might want to change these but usually won't #
####################################################
VB_NUM_THREADS ?= 8
HELP_COLOR ?= 10
BITSTREAM_XSA_DIR ?= .

# This should contain the relative path and file name, or set to null if no platform properties
# It should point to tcl file containing metadata settings for the Vitis Extensible Platform
VITIS_EXT_PLAT_PROPS_LOC ?= null

# This is the action used to fetch a custom bdf file locally to use with the Vivado project
GIT_CLONE_BDF ?= git clone https://github.com/Avnet/bdf -b master $(BDF_DIR)

# These are set to match what the git repo tracks... 
CONSTRAINTS_DIR ?= xdc_user_constraints
TCL_DIR ?= tcl_build_scripts
RTL_DIR ?= rtl_user_src
IP_DIR ?= ip_user

#########################################################################
# These are folders and files that git does NOT track...                #
# NOTE: if these are changed, potentially .gitignore should be updated! #
#########################################################################
VIVADO_LOGS_DIR ?= logs_vivado
PROJ_DIR ?= vivado_prj
BUILD_DIR ?= .$(PROJ_DIR)
TMP_TCL_FILE ?= .__tmp_build.tcl
PDI_DIR ?= pdi
VITIS_XSA_FILE ?= vitis_$(DESIGN_NAME).xsa

# Set this to "null" if you do not want to setup to use local bdf
BDF_DIR ?= bdf_local

# Below vars are useful to be overriden on the cmd line to import tcl from
# any Vivado project. This is useful for integrating any Vivado project into
# Vivado builder without having to export the block design manually.
#
# NOTE: for now, any user constraints MUST be copied over manually and placed
# under $(CONSTRAINTS_DIR)
#
# For example: A Vivado project test.xpr exists at /home/user/work/my_proj. In the
# project the design's name is design_1. The project has a user constraint file
# named pins.xdc
#
#   make extract_block_design IN_PROJ_DIR=/home/user/work/my_proj IN_XPR_NAME=test \
#     IN_DESIGN_NAME=design_1
#
#    cp /home/user/work/my_proj/path-to-constraints/pins.xdc $(CONSTRAINTS_DIR)
#
# This would generate a block design tcl file named $(DESIGN_NAME).tcl with both
# the .xpr and design's name also changed to $(DESIGN_NAME).  Vivado builder can
# now be used to recreate and archive the imported project with just a single
# tcl file and rebuilt with just 'make'
IN_PROJ_DIR ?= $(PROJ_DIR)
IN_XPR_NAME ?= $(DESIGN_NAME)
IN_DESIGN_NAME ?= $(DESIGN_NAME)

# Useful macros
VS := vivado -journal $(VIVADO_LOGS_DIR)/$(DESIGN_NAME).jou -log $(VIVADO_LOGS_DIR)/$(DESIGN_NAME).log -mode batch -notrace -source

WHO_MADE_WHO := $(shell test $(PROJ_DIR)/$(DESIGN_NAME).xpr -nt $(DESIGN_NAME).tcl && echo "extract_block_design" || echo "create_project")
VIVADO_TOOLS := $(shell which vivado)

# Targets
all: check_tools git_bdf chicken_egg build_bitstream_xsa
	@echo;\
	tput setaf 2 ; echo "Built $(DESIGN_NAME) successfully!"; tput sgr0;\
	echo

.PHONY: git_bdf create_project update_xsa build_bitstream_xsa extract_block_design \
	clean realclean clean_logs timing_check write_pdi integrate_tcl help

git_bdf: | $(BDF_DIR)

ifneq ($(BDF_DIR), null)
$(BDF_DIR):
	$(GIT_CLONE_BDF)
else
$(BDF_DIR):
	@echo "Using Vivado's internal BDF library"
endif

chicken_egg:
	$(MAKE) -s $(WHO_MADE_WHO)

# Only bother to check when user enters single 'make'
check_tools:
	@$(call check_tools)

create_project: $(PROJ_DIR)/$(DESIGN_NAME).xpr

build_bitstream_xsa: $(DESIGN_NAME).xsa

write_pdi: $(PDI_DIR)/$(DESIGN_NAME).pdi

write_bit: $(DESIGN_NAME).bit

update_xsa: | $(VIVADO_LOGS_DIR) $(BUILD_DIR) $(BUILD_DIR)/$(DESIGN_NAME).xpr 
	$(VS) $(TCL_DIR)/build_bitstream_xsa.tcl -tclargs $(BUILD_DIR) $(DESIGN_NAME) $(VB_NUM_THREADS) $(BITSTREAM_XSA_DIR)

# Create a new compatible tcl file from an existing Vivado BD tcl file
# The DESIGN_NAME setting determines the final name of the new tcl.
integrate_tcl: | $(VIVADO_LOGS_DIR) $(BDF_DIR)
	$(VS) $(TCL_DIR)/extract_bd.tcl -tclargs null null null $(DESIGN_NAME).tcl $(PROJ_DIR) $(DESIGN_NAME) $(TCL) $(BDF_DIR)

# Overwrite the root folder project tcl with BD from a Vivado project
extract_block_design: | $(VIVADO_LOGS_DIR) $(BDF_DIR) $(PROJ_DIR)/$(DESIGN_NAME).xpr
	$(VS) $(TCL_DIR)/extract_bd.tcl -tclargs $(IN_PROJ_DIR) $(IN_XPR_NAME) $(IN_DESIGN_NAME) $(DESIGN_NAME).tcl $(PROJ_DIR) $(DESIGN_NAME) null $(BDF_DIR)

timing_check: | $(VIVADO_LOGS_DIR) $(BUILD_DIR) $(BITSTREAM_XSA_DIR)/$(DESIGN_NAME).xsa 
	$(VS) $(TCL_DIR)/check_timing.tcl -tclargs open $(BUILD_DIR) $(DESIGN_NAME)

vitis_xsa_export: | $(VIVADO_LOGS_DIR) $(BUILD_DIR)/$(DESIGN_NAME).xpr
	$(VS) $(TCL_DIR)/export_vitis_xsa.tcl -tclargs $(BUILD_DIR) $(DESIGN_NAME) $(BITSTREAM_XSA_DIR)/$(VITIS_XSA_FILE)

$(BITSTREAM_XSA_DIR)/$(DESIGN_NAME).bit: $(BUILD_DIR)/$(DESIGN_NAME).xpr | $(VIVADO_LOGS_DIR) $(BITSTREAM_XSA_DIR)
	$(VS) $(TCL_DIR)/write_bit.tcl -tclargs $(BUILD_DIR) $(DESIGN_NAME) $(VB_NUM_THREADS) $(BITSTREAM_XSA_DIR)

$(PDI_DIR)/$(DESIGN_NAME).pdi: $(BUILD_DIR)/$(DESIGN_NAME).xpr | $(VIVADO_LOGS_DIR) $(PDI_DIR)
	$(VS) $(TCL_DIR)/write_pdi.tcl -tclargs $(BUILD_DIR) $(DESIGN_NAME) $(VB_NUM_THREADS) $(PDI_DIR)

# Update the timestamp on the main .tcl file so that it doesn't trigger a rebuild
#  from the one-time project creation.
# If a user modifies the main Vivado project later so that it becomes newer than
#  the main .tcl, chicken_egg will update it automatically.
$(PROJ_DIR)/$(DESIGN_NAME).xpr: | $(VIVADO_LOGS_DIR) $(BDF_DIR) $(DESIGN_NAME).tcl $(CONSTRAINTS_DIR)
	@if ! [ -f $(PROJ_DIR)/$(DESIGN_NAME).xpr ]; then\
		$(VS) $(TCL_DIR)/create_prj.tcl -tclargs "$(DESIGN_NAME).tcl" $(DESIGN_NAME) $(CONSTRAINTS_DIR) $(RTL_DIR) $(VITIS_EXT_PLAT_PROPS_LOC);\
		touch $(DESIGN_NAME).tcl ;\
	fi

$(TMP_TCL_FILE): $(DESIGN_NAME).tcl | $(VIVADO_LOGS_DIR) $(BDF_DIR) $(BUILD_DIR)
	$(VS) $(TCL_DIR)/create_tmp_build.tcl -tclargs $(DESIGN_NAME).tcl $(TMP_TCL_FILE) $(BUILD_DIR)

$(BUILD_DIR)/$(DESIGN_NAME).xpr: $(TMP_TCL_FILE) | $(VIVADO_LOGS_DIR) $(BDF_DIR) $(CONSTRAINTS_DIR) $(BUILD_DIR)
	rm -rf $(BUILD_DIR)/*
	$(VS) $(TCL_DIR)/create_prj.tcl -tclargs $(TMP_TCL_FILE) $(DESIGN_NAME) $(CONSTRAINTS_DIR) $(RTL_DIR) $(VITIS_EXT_PLAT_PROPS_LOC)

$(BITSTREAM_XSA_DIR)/$(DESIGN_NAME).xsa: $(BUILD_DIR)/$(DESIGN_NAME).xpr | $(VIVADO_LOGS_DIR) $(BDF_DIR) $(BITSTREAM_XSA_DIR)
	$(VS) $(TCL_DIR)/build_bitstream_xsa.tcl -tclargs $(BUILD_DIR) $(DESIGN_NAME) $(VB_NUM_THREADS) $(BITSTREAM_XSA_DIR) $(TCL_DIR)/check_timing.tcl

$(VIVADO_LOGS_DIR):
	mkdir $(VIVADO_LOGS_DIR)

$(PDI_DIR):
	mkdir $(PDI_DIR)

$(BUILD_DIR):
	mkdir $(BUILD_DIR)

$(BITSTREAM_XSA_DIR):
	mkdir $(BITSTREAM_XSA_DIR)

clean_logs:
	rm -rf $(VIVADO_LOGS_DIR)

clean:
	$(MAKE) -s clean_logs
	rm -rf $(BUILD_DIR) .Xil $(PDI_DIR)
	rm -f $(TMP_TCL_FILE) $(BITSTREAM_XSA_DIR)/$(DESIGN_NAME).bit $(BITSTREAM_XSA_DIR)/$(DESIGN_NAME).xsa wdi_info.xml $(BITSTREAM_XSA_DIR)/$(VITIS_XSA_FILE)

realclean:
	rm -rf $(BDF_DIR)
	$(MAKE) -s clean
	rm -rf $(PROJ_DIR)

define check_tools
	@if [[ -z "$(VIVADO_TOOLS)" ]]; then\
		echo "ERROR: Cannot find Vivado!";\
		echo "       Please source the Vitis/Vivado settings64.sh";\
	fi;\
	if [[ -z "$(VIVADO_TOOLS)" ]]; then\
		exit -1;\
	fi
endef

help:
	@echo
	@echo " MIT License"
	@echo " Copyright (c) 2025 FredKellerman"
	@echo 
	@echo " Permission is hereby granted, free of charge, to any person obtaining a copy"
	@echo " of this software and associated documentation files (the "Software"), to"
	@echo " deal in the Software without restriction, including without limitation the"
	@echo " rights to use, copy, modify, merge, publish, distribute, sublicense, and/or"
	@echo " sell copies of the Software, and to permit persons to whom the Software is"
	@echo " furnished to do so, subject to the following conditions:"
	@echo
	@echo " The above copyright notice and this permission notice shall be included in"
	@echo " all copies or substantial portions of the Software."
	@echo
	@echo " THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR"
	@echo " IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,"
	@echo " FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL"
	@echo " THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER"
	@echo " LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,"
	@echo " OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN"
	@echo " THE SOFTWARE."
	@echo
	@tput setaf $(HELP_COLOR);
	@echo "Version 2.0.0 Overview:"
	@echo
	@echo "Entering just 'make' will use the local file $(DESIGN_NAME).tcl to create a full Vivado project \
located under the dir: $(PROJ_DIR). The project will then be copied to a hidden 2nd project which will be used \
to generate an XSA file. The final timing of the design will be analyzed and reported."
	@echo
	@echo "Constraint file(s) of any name found under the dir './$(CONSTRAINTS_DIR)' will be added to the \
Vivado project."
	@echo
	@echo "Verilog/VHDL RTL source file(s) of any name found under the dir './$(RTL_DIR)' will be added to the \
Vivado project."
	@echo
	@echo "Several targets are useful for editing or enhancing the Vivado design:"
	@echo
	@echo " 'make create_project' - creates the full Vivado prj but will NOT build it."
	@echo " 'make build_bitstream_xsa' - attempts to create the xsa file from the Vivado prj"
	@echo " 'make extract_block_design' - updates $(DESIGN_NAME).tcl with the latest saved Vivado prj"
	@echo " 'make write_bit' - for MPSoC/Zynq, generates the bitstream"
	@echo " 'make vitis_xsa_export' - Skips full-synth & place-route, quick xsa for Vitis platforms"
	@echo " 'make write_pdi' - for Versal, generates a PDI file from the design"
	@echo " 'make clean' - removes the hidden Vivado project, xsa, bitstream/pdi and logs PERMANENTLY!"
	@echo " 'make realclean' - removes the main Vivado prj and runs make clean all are deleted PERMANENTLY!"
	@echo " 'make clean_logs' - removes only the logs found under: $(VIVADO_LOGS_DIR)"
	@echo " 'make integrate_tcl TCL=[path/name.tcl]' - Integrates an existing Vivado Block Design into builder"
	@echo
	@echo "For the first time to set this up: Change the Makefile design name and paths to meet your needs -> \
'make integrate_tcl TCL=[my old BD tcl path/file]' -> Copy over user constraints and RTL source -> \
'make create_project' -> Edit design in Vivado -> Ensure it builds and meets timing in Vivado, save, \
close -> 'make' to generate the xsa -> test the design on hardware -> commit changes to version \
control or save design .tcl -> Push your changes to a server -> Clean up and remove Vivado project."
	@echo
	@echo "After $(DESIGN_NAME).tcl is created or after cloning a fresh repo, entering 'make' will build \
the .xsa and a bitstream if using MPSoC.  To edit or change the design, open the Vivado gui \
$PROJ_DIR)/$(DESIGN_NAME).xpr project and perform your edits and tests.  After you are done, exit \
out of Vivado and then enter 'make' to update the .xsa and bitstream.  If everything is working, commit \
the .tcl changes to your repo."
	@echo
	@echo "Note: 'make extract_block_design' with reassigned vars can also be used to import \
a block design from any Vivado project."
	@echo "For example: A Vivado project test.xpr exists at /home/user/work/my_proj. In the \
project the design's name is design_1. The project has a user constraint file named pins.xdc"
	@echo
	@echo "   'make extract_block_design IN_PROJ_DIR=/home/user/work/my_proj IN_XPR_NAME=test \
IN_DESIGN_NAME=design_1'"
	@echo "   'cp /home/user/work/my_proj/constraints-path/pins.xdc ./$(CONSTRAINTS_DIR)'"
	@echo
	@echo "The above make cmd will extract the external Vivado project's block design and \
create a new master tcl file for Vivado builder but not build it.  Enter 'make' to build."
	@echo
	@echo "VB_NUM_THREADS sets how many CPU threads Vivado uses. The default setting is \
$(VB_NUM_THREADS), you may override this setting on the make cmd line to match your own \
compute capabilities."
	@tput sgr0;
