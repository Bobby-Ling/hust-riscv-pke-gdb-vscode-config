#!/bin/bash

echo "START_KERNEL"

echo "start at $(pwd)"
# make gdb-clean
kill -9 $(lsof -i:9824 -t)
kill -9 $(lsof -i:3333 -t)

# spike -l --log=spike.log obj/riscv-pke obj/app_*
# 效果是spike先后台运行, 但是依然显示spike的输出
spike --rbb-port=9824 --halted obj/riscv-pke /bin/app_shell 2>&1 | tee spike.log &
# spike --rbb-port=9824 --halted -p2 obj/riscv-pke /bin/app_shell 2>&1 | tee spike.log &

sleep 0.1s

openocd -f ./singlecore.spike.cfg > openocd.log 2>&1
# openocd -f ./multicore.spike.cfg > openocd.log 2>&1

# openocd -f ./.spike.cfg -c "reset halt" 2>&1 | tee openocd.log

# telnet localhost 4444
# reset
# halt
# bp 0x0000000080001d32 4
# rbp 0x0000000080001d32
# step
# resume

# riscv64-unknown-elf-gdb obj/riscv-pke -ex "target ext :3333" -ex "monitor reset halt" -ex "b m_start" -ex "c" -ex "layout src" -ex "focus cmd"

echo STARTED
