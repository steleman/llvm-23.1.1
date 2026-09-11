# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-linux %s -o %t.o
# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-readobj -r %t.so | FileCheck --check-prefix=RELOCS %s
# RUN: llvm-objdump --no-print-imm-hex --no-show-raw-insn -d %t.so | \
# RUN:   FileCheck --check-prefix=DISAS %s

## R_AARCH64_TLSIE_MOVW_GOTTPREL_G1 / _G0_NC materialize the offset of a TLS
## symbol's GOT entry from the GOT base, for initial-exec in the large code
## model. The GOT entry itself holds the thread-pointer-relative offset and
## takes a TLS_TPREL64 dynamic relocation.

.text
.global _start
_start:
## Two plain GOT references first, so the TLS entry is not at offset zero.
  adrp x2, :got:a
  ldr  x2, [x2, :got_lo12:a]
  adrp x3, :got:b
  ldr  x3, [x3, :got_lo12:b]

  movz x0, #:gottprel_g1:tlsvar
  movk x0, #:gottprel_g0_nc:tlsvar
  ldr  x0, [x1, x0]

.global a, b
.data
a: .xword 0
b: .xword 0

.section .tdata,"awT",@progbits
.global tlsvar
tlsvar: .word 42

## The two plain entries come first, so the TLS entry sits at offset 16.
# RELOCS:      Relocations [
# RELOCS-NEXT:   Section ({{.*}}) .rela.dyn {
# RELOCS-NEXT:     0x[[#%X,GOT:]] R_AARCH64_GLOB_DAT a 0x0
# RELOCS-NEXT:     0x[[#%X,GOT+8]] R_AARCH64_GLOB_DAT b 0x0
# RELOCS-NEXT:     0x[[#%X,GOT+16]] R_AARCH64_TLS_TPREL64 tlsvar 0x0
# RELOCS-NEXT:   }
# RELOCS-NEXT: ]

# DISAS:      movz    x0, #0, lsl #16
# DISAS-NEXT: movk    x0, #16
# DISAS-NEXT: ldr     x0, [x1, x0]

## In an executable, initial-exec against a non-preemptible symbol is normally
## relaxed to local-exec by writing the thread-pointer-relative value into the
## relocated field. That rewrite is only valid when the load consuming the
## value is itself relocated and can be rewritten too. This sequence indexes
## the GOT base with a plain register-offset LDR carrying no relocation, so the
## relaxation must not happen: the GOT entry has to survive, or the LDR would
## dereference a thread-pointer offset.
##
# RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-linux %S/Inputs/aarch64-tlsie-movw-exe.s -o %t2.o
# RUN: ld.lld -pie %t2.o -o %t2.exe
# RUN: llvm-readelf -S %t2.exe | FileCheck --check-prefix=EXE-SEC %s
# RUN: llvm-objdump --no-print-imm-hex --no-show-raw-insn -d %t2.exe | \
# RUN:   FileCheck --check-prefix=EXE-DISAS %s

## A GOT entry must still be allocated rather than optimized away.
# EXE-SEC: .got PROGBITS {{[0-9a-f]+}} {{[0-9a-f]+}} 000008

## The chunks still hold a GOT offset, and the GOT load is still present.
# EXE-DISAS:      movz    x0, #0, lsl #16
# EXE-DISAS-NEXT: movk    x0, #0
# EXE-DISAS-NEXT: ldr     x0, [x1, x0]
