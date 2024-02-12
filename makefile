################################################################################
################################## Constants ###################################

# Root source and build directories:
SOURCE_DIR := source
BUILD_DIR := build

# Config file name:
CONFIG_FILE := config.mk

################################################################################
################################# Config file ##################################

# Check if config file exists and include it:
ifeq ($(wildcard $(CONFIG_FILE)),)
$(info Warning: Config file '$(CONFIG_FILE)' not found.)
else
include $(CONFIG_FILE)
endif

# Check that TARGET has been specified:
ifeq ($(TARGET),)
$(error TARGET not specified)
endif

# Check that PROGRAMMER is specified:
ifeq ($(PROGRAMMER),)
$(error PROGRAMMER not specified)
endif

################################################################################
################################# Target file ##################################

# Generate target file name:
TARGET_FILE := $(SOURCE_DIR)/$(TARGET).target.mk

# Check that TARGET_FILE exists and include it:
ifeq ($(wildcard $(TARGET_FILE)),)
$(error Target file '$(TARGET_FILE)' not found)
else
include $(TARGET_FILE)
endif

# Check that MCU is specified:
ifeq ($(MCU),)
$(error MCU not specified)
endif

# Check that F_CPU is specified:
ifeq ($(F_CPU),)
$(error F_CPU not specified)
endif

# Check that SOURCE_FILES is specified:
ifeq ($(SOURCE_FILES),)
$(error SOURCE_FILES not specified)
endif

################################################################################
################################ Variable setup ################################

# Prepend source directory to all source files and expand wildcards:
SOURCE_FILES := $(SOURCE_FILES:%=$(SOURCE_DIR)/%)
SOURCE_FILES := $(wildcard $(SOURCE_FILES))

# Check that SOURCE_FILES isn't empty:
ifeq ($(SOURCE_FILES),)
$(error No valid files found in SOURCE_FILES)
endif

# Generate ELF and ASM file names:
ELF_FILE := $(BUILD_DIR)/$(TARGET).elf
ASM_FILE := $(BUILD_DIR)/$(TARGET).asm

# Generate object and dependecy file names:
OBJECT_FILES := $(SOURCE_FILES:$(SOURCE_DIR)/%=$(BUILD_DIR)/%)
OBJECT_FILES := $(OBJECT_FILES:.c=.c.o)
OBJECT_FILES := $(OBJECT_FILES:.s=.s.o)
DEPENDENCY_FILES := $(SOURCE_FILES:$(SOURCE_DIR)/%=$(BUILD_DIR)/%)
DEPENDENCY_FILES := $(DEPENDENCY_FILES:.c=.c.d)
DEPENDENCY_FILES := $(DEPENDENCY_FILES:.s=.s.d)

# Compiler flags for generating dependency files (see 'Dependency files' section below):
DEPENDENCY_FLAGS = -MT $@ -MMD -MP -MF $(<:$(SOURCE_DIR)/%=$(BUILD_DIR)/%.d)

################################################################################
############################# Targets and recipes ##############################

.PHONY: elf
elf: $(ELF_FILE)

.PHONY: asm
asm: $(ASM_FILE)

.PHONY: flash
flash: $(ELF_FILE)
	avrdude -c "$(PROGRAMMER)" -p "$(MCU)" -U flash:w:$<

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)

$(ELF_FILE): $(OBJECT_FILES) $(TARGET_FILE)
	avr-gcc -mmcu="$(MCU)" -DF_CPU="$(F_CPU)" $(COMPILER_FLAGS) -g -o $@ $(OBJECT_FILES)

$(ASM_FILE): $(ELF_FILE)
	 avr-objdump -D --section=.data --section=.text --source-comment $< > $@

$(BUILD_DIR)/%.c.o: $(SOURCE_DIR)/%.c $(BUILD_DIR)/%.c.d $(TARGET_FILE)
	@mkdir -p $(@D)
	avr-gcc -mmcu="$(MCU)" -DF_CPU="$(F_CPU)" $(DEPENDENCY_FLAGS) $(COMPILER_FLAGS) -g -c -o $@ $<

$(BUILD_DIR)/%.s.o: $(SOURCE_DIR)/%.s $(BUILD_DIR)/%.s.d $(TARGET_FILE)
	@mkdir -p $(@D)
	avr-gcc -mmcu="$(MCU)" -DF_CPU="$(F_CPU)" $(DEPENDENCY_FLAGS) $(COMPILER_FLAGS) -x assembler-with-cpp -g -c -o $@ $<

################################################################################
############################### Dependency files ###############################

# See https://make.mad-scientist.net/papers/advanced-auto-dependency-generation/
# for information about how the dependencies are managed.

$(DEPENDENCY_FILES): ;

include $(DEPENDENCY_FILES)

################################################################################
