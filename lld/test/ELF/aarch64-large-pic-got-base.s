# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-linux %s -o %t.o
# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-readelf -S %t.so | FileCheck --check-prefix=SEC %s
# RUN: llvm-objdump --no-show-raw-insn -d %t.so | FileCheck --check-prefix=DISAS %s

## The large position-independent code model computes the GOT base with an
## unlimited PC-relative range: take the PC with ADR, add a 64-bit
## PC-relative displacement built from four MOVW_PREL chunks, then index the
## GOT with a MOVW_GOTOFF chunk sequence.
##
## Each R_AARCH64_MOVW_PREL_G* computes S + A - P against its own instruction
## address P, so every chunk carries an addend equal to its offset from the
## ADR, making all four slices of the same value _GLOBAL_OFFSET_TABLE_ - .Lpc.

.text
.global _start
_start:
.Lpc:
  adr  x16, .Lpc
  movz x17, #:prel_g3:_GLOBAL_OFFSET_TABLE_+4
  movk x17, #:prel_g2_nc:_GLOBAL_OFFSET_TABLE_+8
  movk x17, #:prel_g1_nc:_GLOBAL_OFFSET_TABLE_+12
  movk x17, #:prel_g0_nc:_GLOBAL_OFFSET_TABLE_+16
  add  x16, x16, x17

  movz x0, #:gotoff_g3:sym
  movk x0, #:gotoff_g2_nc:sym
  movk x0, #:gotoff_g1_nc:sym
  movk x0, #:gotoff_g0_nc:sym
  ldr  x0, [x16, x0]

.data
.global sym
sym: .xword 0

## .text is at 0x102b0 and the GOT at 0x20380, so the displacement materialized
## into x17 is 0x20380 - 0x102b0 = 0x100d0, and x16 + x17 is the GOT base.
# SEC: .got PROGBITS 0000000000020380

# DISAS:      102b0: adr     x16, 0x102b0
# DISAS-NEXT: movz    x17, #0x0, lsl #48
# DISAS-NEXT: movk    x17, #0x0, lsl #32
# DISAS-NEXT: movk    x17, #0x1, lsl #16
# DISAS-NEXT: movk    x17, #0xd0
# DISAS-NEXT: add     x16, x16, x17
## sym is the only GOT entry, so its offset from the GOT base is zero.
# DISAS-NEXT: movz    x0, #0x0, lsl #48
# DISAS-NEXT: movk    x0, #0x0, lsl #32
# DISAS-NEXT: movk    x0, #0x0, lsl #16
# DISAS-NEXT: movk    x0, #0x0
# DISAS-NEXT: ldr     x0, [x16, x0]
