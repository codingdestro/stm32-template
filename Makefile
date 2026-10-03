PREFIX ?= arm-none-eabi-
BUILD_DIR := build
TARGET := firmware

CC := $(PREFIX)gcc
OBJCOPY := $(PREFIX)objcopy
SIZE := $(PREFIX)size

LIBOPENCM3_DIR := /home/nerd/Development/hardware/libs/libopencm3
CMSIS_CORE_DIR := /home/nerd/Development/hardware/libs/CMSIS_5/CMSIS/Core/Include
CMSIS_DEVICE_DIR := /home/nerd/Development/hardware/libs/cmsis-device-f1
PROJECT_INCLUDE_DIR := include
LIBOPENCM3 := $(LIBOPENCM3_DIR)/lib/libopencm3_stm32f1.a

CPU_FLAGS := -mcpu=cortex-m3 -mthumb -mfloat-abi=soft
COMMON_FLAGS := $(CPU_FLAGS) -DSTM32F103x6 -DSTM32F1 \
	-ffunction-sections -fdata-sections -fno-common -fno-builtin \
	-Wall -Wextra -Wshadow -Wundef -Wdouble-promotion -Wformat=2 \
	-g3 -Og
CFLAGS := $(COMMON_FLAGS) -std=c11 \
	-I$(PROJECT_INCLUDE_DIR) -I$(LIBOPENCM3_DIR)/include \
	-I$(CMSIS_CORE_DIR) -I$(CMSIS_DEVICE_DIR)/Include
ASFLAGS := $(CPU_FLAGS) -x assembler-with-cpp -g3
LDFLAGS := $(CPU_FLAGS) -nostartfiles --specs=nano.specs --specs=nosys.specs \
	-Wl,--gc-sections -Wl,-T,ld/stm32f103c6.ld -Wl,-Map,$(BUILD_DIR)/$(TARGET).map

# Every C file below src/ is compiled automatically, including subdirectories.
APP_SOURCES := $(sort $(shell find src -type f -name '*.c'))
SOURCES := $(APP_SOURCES) $(CMSIS_DEVICE_DIR)/Source/Templates/system_stm32f1xx.c
STARTUP := $(CMSIS_DEVICE_DIR)/Source/Templates/gcc/startup_stm32f103x6.s
OBJECTS := $(patsubst %.c,$(BUILD_DIR)/%.o,$(SOURCES)) \
	$(patsubst %.s,$(BUILD_DIR)/%.o,$(STARTUP))
DEPS := $(OBJECTS:.o=.d)

.DEFAULT_GOAL := all

all: $(BUILD_DIR)/$(TARGET).bin

$(LIBOPENCM3):
	$(MAKE) -C $(LIBOPENCM3_DIR) TARGETS=stm32/f1

$(BUILD_DIR)/$(TARGET).elf: $(OBJECTS) $(LIBOPENCM3) | $(BUILD_DIR)
	$(CC) $(LDFLAGS) $(OBJECTS) $(LIBOPENCM3) -Wl,--start-group -lc -lm -Wl,--end-group -o $@
	$(SIZE) $@

$(BUILD_DIR)/$(TARGET).bin: $(BUILD_DIR)/$(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(BUILD_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

$(BUILD_DIR)/%.o: %.s
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD_DIR):
	mkdir -p $@

flash: $(BUILD_DIR)/$(TARGET).bin
	st-flash write $< 0x08000000

openocd:
	openocd -f interface/stlink.cfg -f target/stm32f1x.cfg

gdb: $(BUILD_DIR)/$(TARGET).elf
	$(PREFIX)gdb $< -ex 'target extended-remote localhost:3333' -ex 'monitor reset halt'

check-target: $(BUILD_DIR)/$(TARGET).elf
	bash scripts/check-target.sh $<

clean:
	rm -rf $(BUILD_DIR)

-include $(DEPS)

.PHONY: all flash openocd gdb check-target clean
