# we assume that the utilities from RISC-V cross-compiler (i.e., riscv64-unknown-elf-gcc and etc.)
# are in your system PATH. To check if your environment satisfies this requirement, simple use 
# `which` command as follows:
# $ which riscv64-unknown-elf-gcc
# if you have an output path, your environment satisfy our requirement.

# ---------------------	macros --------------------------
CROSS_PREFIX 	:= riscv64-unknown-elf-
CC 				:= $(CROSS_PREFIX)gcc
AR 				:= $(CROSS_PREFIX)ar
RANLIB        	:= $(CROSS_PREFIX)ranlib

SRC_DIR        	:= .
OBJ_DIR 		:= obj
SPROJS_INCLUDE 	:= -I.  

HOSTFS_ROOT := hostfs_root
ifneq (,)
  march := -march=
  is_32bit := $(findstring 32,$(march))
  mabi := -mabi=$(if $(is_32bit),ilp32,lp64)
endif

CFLAGS        := -Wall -Werror  -fno-builtin -nostdlib -D__NO_INLINE__ -mcmodel=medany -g -O0 -std=gnu99 -Wno-unused -Wno-attributes -fno-delete-null-pointer-checks -fno-PIE $(march) -fno-omit-frame-pointer -gdwarf-3
COMPILE       	:= $(CC) -MMD -MP $(CFLAGS) $(SPROJS_INCLUDE)

#---------------------	utils -----------------------
UTIL_CPPS 	:= util/*.c

UTIL_CPPS  := $(wildcard $(UTIL_CPPS))
UTIL_OBJS  :=  $(addprefix $(OBJ_DIR)/, $(patsubst %.c,%.o,$(UTIL_CPPS)))


UTIL_LIB   := $(OBJ_DIR)/util.a

#---------------------	kernel -----------------------
KERNEL_LDS  	:= kernel/kernel.lds
KERNEL_CPPS 	:= \
	kernel/*.c \
	kernel/machine/*.c \
	kernel/util/*.c

KERNEL_ASMS 	:= \
	kernel/*.S \
	kernel/machine/*.S \
	kernel/util/*.S

KERNEL_CPPS  	:= $(wildcard $(KERNEL_CPPS))
KERNEL_ASMS  	:= $(wildcard $(KERNEL_ASMS))
KERNEL_OBJS  	:=  $(addprefix $(OBJ_DIR)/, $(patsubst %.c,%.o,$(KERNEL_CPPS)))
KERNEL_OBJS  	+=  $(addprefix $(OBJ_DIR)/, $(patsubst %.S,%.o,$(KERNEL_ASMS)))

KERNEL_TARGET = $(OBJ_DIR)/riscv-pke


#---------------------	spike interface library -----------------------
SPIKE_INF_CPPS 	:= spike_interface/*.c

SPIKE_INF_CPPS  := $(wildcard $(SPIKE_INF_CPPS))
SPIKE_INF_OBJS 	:=  $(addprefix $(OBJ_DIR)/, $(patsubst %.c,%.o,$(SPIKE_INF_CPPS)))


SPIKE_INF_LIB   := $(OBJ_DIR)/spike_interface.a


#---------------------	user   -----------------------
# 用户库文件
USER_LIB_FILES := user/user_lib.c
USER_LIB_OBJS := $(addprefix $(OBJ_DIR)/, $(patsubst %.c,%.o,$(USER_LIB_FILES)))

# 自动查找所有用户应用程序源文件（排除 user_lib.c）
USER_APP_SRCS := $(filter-out $(USER_LIB_FILES), $(wildcard user/*.c))
USER_APP_BASES := $(basename $(notdir $(USER_APP_SRCS)))
USER_APP_TARGETS := $(patsubst %,$(HOSTFS_ROOT)/bin/%,$(USER_APP_BASES))

USER_INIT := bin/app_shell
USER_TARGET := $(HOSTFS_ROOT)/$(USER_INIT)

#------------------------targets------------------------
$(OBJ_DIR):
	@-mkdir -p $(OBJ_DIR)	
	@-mkdir -p $(dir $(UTIL_OBJS))
	@-mkdir -p $(dir $(SPIKE_INF_OBJS))
	@-mkdir -p $(dir $(KERNEL_OBJS))
	@-mkdir -p $(dir $(USER_LIB_OBJS))
	@-mkdir -p $(OBJ_DIR)/user
	@-mkdir -p $(HOSTFS_ROOT)/bin
	
$(OBJ_DIR)/%.o : %.c
	@echo "compiling" $<
	@$(COMPILE) -c $< -o $@

$(OBJ_DIR)/%.o : %.S
	@echo "compiling" $<
	@$(COMPILE) -c $< -o $@

$(UTIL_LIB): $(OBJ_DIR) $(UTIL_OBJS)
	@echo "linking " $@	...	
	@$(AR) -rcs $@ $(UTIL_OBJS) 
	@echo "Util lib has been build into" \"$@\"
	
$(SPIKE_INF_LIB): $(OBJ_DIR) $(UTIL_OBJS) $(SPIKE_INF_OBJS)
	@echo "linking " $@	...	
	@$(AR) -rcs $@ $(SPIKE_INF_OBJS) $(UTIL_OBJS)
	@echo "Spike lib has been build into" \"$@\"

$(KERNEL_TARGET): $(OBJ_DIR) $(UTIL_LIB) $(SPIKE_INF_LIB) $(KERNEL_OBJS) $(KERNEL_LDS)
	@echo "linking" $@ ...
	@$(COMPILE) $(KERNEL_OBJS) $(UTIL_LIB) $(SPIKE_INF_LIB) -o $@ -T $(KERNEL_LDS)
	@echo "PKE core has been built into" \"$@\"

# 通用规则：为每个用户应用程序创建目标
$(HOSTFS_ROOT)/bin/% : $(OBJ_DIR)/user/%.o $(USER_LIB_OBJS) $(UTIL_LIB)
	@echo "linking" $@	...	
	@$(COMPILE) --entry=main $< $(USER_LIB_OBJS) $(UTIL_LIB) -o $@
	@echo "User app has been built into" \"$@\"
	@if [ "$@" = "$(USER_TARGET)" ]; then cp $@ $(OBJ_DIR); fi

# 特殊的依赖规则：确保用户程序的.o文件被正确创建
$(OBJ_DIR)/user/%.o : user/%.c
	@echo "compiling" $<
	@$(COMPILE) -c $< -o $@

-include $(wildcard $(OBJ_DIR)/*/*.d)
-include $(wildcard $(OBJ_DIR)/*/*/*.d)

.DEFAULT_GOAL := $(all)

all: $(KERNEL_TARGET) $(USER_APP_TARGETS)
.PHONY:all

run: $(KERNEL_TARGET) $(USER_APP_TARGETS)
	@echo "********************HUST PKE********************"
	spike -p2 $(KERNEL_TARGET) /$(USER_INIT)

# need openocd!
gdb:$(KERNEL_TARGET) $(USER_APP_TARGETS)
	spike --rbb-port=9824 --halted -p2 $(KERNEL_TARGET) /$(USER_INIT) 2>&1 | tee spike.log &
	@sleep 0.2
	openocd -f ./multicore.spike.cfg > openocd.log 2>&1 &
	@sleep 0.2
	riscv64-unknown-elf-gdb -nx -command=./.gdbinit
	# riscv64-unknown-elf-gdb -command=./.gdbinit
	
gdb_p1:$(KERNEL_TARGET) $(USER_APP_TARGETS)
	spike --rbb-port=9824 --halted -p1 $(KERNEL_TARGET) /$(USER_INIT) 2>&1 | tee spike.log &
	@sleep 0.2
	openocd -f ./singlecore.spike.cfg > openocd.log 2>&1 &
	@sleep 0.2
	riscv64-unknown-elf-gdb -nx -command=./.gdbinit
	# riscv64-unknown-elf-gdb -command=./.gdbinit

# clean gdb. need openocd!
gdb_clean:
	@-kill -9 $$(lsof -i:9824 -t)
	@-kill -9 $$(lsof -i:3333 -t)
	@sleep 1

objdump:
	@targets="$(KERNEL_TARGET) $(USER_TARGET) $(USER_APP_TARGETS)"; \
	for target in $$targets; do \
		riscv64-unknown-elf-objdump -d $$target > $(OBJ_DIR)/$$(basename $$target).asm; \
		echo dumped $(OBJ_DIR)/$$(basename $$target).asm; \
	done

cscope:
	find ./ -name "*.c" > cscope.files
	find ./ -name "*.h" >> cscope.files
	find ./ -name "*.S" >> cscope.files
	find ./ -name "*.lds" >> cscope.files
	cscope -bqk

format:
	@python ./format.py ./

clean:
	rm -fr ${OBJ_DIR} ${HOSTFS_ROOT}/bin