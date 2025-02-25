target extended-remote localhost:3333
monitor reset halt
symbol-file obj/riscv-pke
b m_start
c
# m_start中会timerinit()
s_start
c

define disable_timer
  set $old_mie = $mie
  # 清除MIE_MTIE
  set $mie = $mie & ~0x80
end

define enable_timer
  # 恢复MIE_MTIE
  set $mie = $old_mie
end

# m_start后禁用timer
disable_timer
