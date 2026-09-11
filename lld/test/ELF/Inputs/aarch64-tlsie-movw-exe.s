.text
.global _start
_start:
  movz x0, #:gottprel_g1:tlsvar
  movk x0, #:gottprel_g0_nc:tlsvar
  ldr  x0, [x1, x0]
  ret

.section .tdata,"awT",@progbits
.global tlsvar
tlsvar: .word 42
