# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-linux %s -o %t.o
# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-readobj -r %t.so | FileCheck --check-prefix=RELOCS %s
# RUN: llvm-objdump --no-print-imm-hex --no-show-raw-insn -d %t.so | \
# RUN:   FileCheck --check-prefix=DISAS %s

## R_AARCH64_MOVW_GOTOFF_G* materialize the offset of a symbol's GOT entry from
## the GOT base in 16-bit chunks, for the large position-independent code
## model. AAELF64 calculates them as G(GDAT(S)) - GOT, and
## _GLOBAL_OFFSET_TABLE_ is the start of .got, so the value is the symbol's
## offset within .got.

.text
.global _start
_start:
## Pull three earlier symbols into the GOT so that sym's entry is not at
## offset zero.
  adrp x2, :got:a
  ldr  x2, [x2, :got_lo12:a]
  adrp x3, :got:b
  ldr  x3, [x3, :got_lo12:b]
  adrp x4, :got:c
  ldr  x4, [x4, :got_lo12:c]

  movz x0, #:gotoff_g3:sym
  movk x0, #:gotoff_g2_nc:sym
  movk x0, #:gotoff_g1_nc:sym
  movk x0, #:gotoff_g0_nc:sym
  ldr  x0, [x1, x0]

.data
.global a, b, c, sym
a:   .xword 0
b:   .xword 0
c:   .xword 0
sym: .xword 0

## The GOT entries are laid out in reference order, so sym is the fourth and
## its offset from the GOT base is 3 * 8 = 24.
# RELOCS:      Relocations [
# RELOCS-NEXT:   Section ({{.*}}) .rela.dyn {
# RELOCS-NEXT:     0x[[#%X,GOT:]] R_AARCH64_GLOB_DAT a 0x0
# RELOCS-NEXT:     0x[[#%X,GOT+8]] R_AARCH64_GLOB_DAT b 0x0
# RELOCS-NEXT:     0x[[#%X,GOT+16]] R_AARCH64_GLOB_DAT c 0x0
# RELOCS-NEXT:     0x[[#%X,GOT+24]] R_AARCH64_GLOB_DAT sym 0x0
# RELOCS-NEXT:   }
# RELOCS-NEXT: ]

# DISAS:      movz    x0, #0, lsl #48
# DISAS-NEXT: movk    x0, #0, lsl #32
# DISAS-NEXT: movk    x0, #0, lsl #16
# DISAS-NEXT: movk    x0, #24
# DISAS-NEXT: ldr     x0, [x1, x0]
