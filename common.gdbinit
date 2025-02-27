monitor reset halt
symbol-file obj/riscv-pke
b m_start
c
# m_start中会timerinit()
b s_start
c

define disable_timer
  set $old_mie = $mie
  # 清除MIE_MTIE
  set $mie = $mie & ~0x80
  echo timer disabled\n
end

alias tmoff=disable_timer

define enable_timer
  # 恢复MIE_MTIE
  set $mie = $old_mie
  echo timer enabled\n
end

alias tmon=enable_timer

# m_start后禁用timer
disable_timer
