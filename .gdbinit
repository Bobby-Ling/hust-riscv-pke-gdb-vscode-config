target extended-remote localhost:3333
monitor reset halt
symbol-file obj/riscv-pke
b m_start
c