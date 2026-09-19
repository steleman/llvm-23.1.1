; RUN: llc -mtriple=riscv64 -code-model=large -relocation-model=static \
; RUN:   -verify-machineinstrs -o - %s | FileCheck %s --check-prefix=STATIC
; RUN: llc -mtriple=riscv64 -code-model=large -relocation-model=static \
; RUN:   -verify-machineinstrs -function-sections -o - %s \
; RUN:   | FileCheck %s --check-prefix=FUNCSEC
; RUN: llc -mtriple=riscv64 -code-model=large -relocation-model=pic \
; RUN:   -riscv-large-pic -verify-machineinstrs -o - %s \
; RUN:   | FileCheck %s --check-prefix=PIC
; RUN: llc -mtriple=riscv64 -code-model=large -relocation-model=pic \
; RUN:   -riscv-large-pic -verify-machineinstrs -function-sections -o - %s \
; RUN:   | FileCheck %s --check-prefix=PICFS
; RUN: llc -mtriple=riscv64 -code-model=medium -relocation-model=pic \
; RUN:   -verify-machineinstrs -o - %s | FileCheck %s --check-prefix=MEDIUM

;; The large code model reaches a jump table with auipc/addi, like its constant
;; pools, so the table has to stay within +/-2GiB of the code. .rodata may be
;; further away, where the link fails with "relocation R_RISCV_PCREL_HI20 out
;; of range", so the table is emitted in the function's own section instead.
;; This applies to the position-dependent large model and to the prototype
;; position-independent one alike. Other code models keep the table in
;; .rodata.

; STATIC-LABEL: dispatch:
; STATIC:         auipc a1, %pcrel_hi(.LJTI0_0)
; STATIC-NOT:     .section
; STATIC:       .LJTI0_0:
; STATIC-NEXT:    .quad .LBB0_2

; FUNCSEC:        .section .text.dispatch,"ax",@progbits
; FUNCSEC-LABEL: dispatch:
; FUNCSEC:         auipc a1, %pcrel_hi(.LJTI0_0)
; FUNCSEC-NOT:     .section
; FUNCSEC:       .LJTI0_0:
; FUNCSEC-NEXT:    .quad .LBB0_2

;; The prototype emits the function's indirection table into .data.rel.ro
;; from emitFunctionBodyEnd and then switches back to the function's section,
;; so the jump table that follows still lands next to the code.
; PIC-LABEL: dispatch:
; PIC:         auipc a1, %pcrel_hi(.LJTI0_0)
; PIC:         .section .data.rel.ro,"aw",@progbits
; PIC-NEXT:    .p2align 3, 0x0
; PIC-NEXT:  .Lrvlp_tbl.dispatch:
; PIC:         .quad a
; PIC-NEXT:    .text
; PIC-NOT:     .section
; PIC:       .LJTI0_0:
; PIC-NEXT:    .word .LBB0_2-.LJTI0_0

; PICFS:        .section .text.dispatch,"ax",@progbits
; PICFS:        .section .data.rel.ro,"aw",@progbits
; PICFS:        .quad a
; PICFS-NEXT:   .section .text.dispatch,"ax",@progbits
; PICFS-NOT:    .section
; PICFS:      .LJTI0_0:
; PICFS-NEXT:   .word .LBB0_2-.LJTI0_0

; MEDIUM-LABEL: dispatch:
; MEDIUM:         auipc a1, %pcrel_hi(.LJTI0_0)
; MEDIUM:         .section .rodata,"a",@progbits
; MEDIUM-NEXT:    .p2align 2, 0x0
; MEDIUM-NEXT:  .LJTI0_0:
; MEDIUM-NEXT:    .word .LBB0_2-.LJTI0_0

declare void @a()
declare void @b()
declare void @c()
declare void @d()
declare void @e()
declare void @f()
declare void @g()

define void @dispatch(i32 %x) {
entry:
  switch i32 %x, label %exit [
    i32 0, label %l0
    i32 1, label %l1
    i32 2, label %l2
    i32 3, label %l3
    i32 4, label %l4
    i32 5, label %l5
    i32 6, label %l6
  ]
l0:
  call void @a()
  br label %exit
l1:
  call void @b()
  br label %exit
l2:
  call void @c()
  br label %exit
l3:
  call void @d()
  br label %exit
l4:
  call void @e()
  br label %exit
l5:
  call void @f()
  br label %exit
l6:
  call void @g()
  br label %exit
exit:
  ret void
}
