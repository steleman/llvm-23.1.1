; RUN: llc -mtriple=riscv64 -code-model=large -relocation-model=pic \
; RUN:   -o - %s | FileCheck %s
;
; Combinations that must keep working alongside it.
; RUN: llc -mtriple=riscv64 -code-model=large -o /dev/null %s
; RUN: llc -mtriple=riscv64 -code-model=large -relocation-model=dynamic-no-pic -o /dev/null %s
; RUN: llc -mtriple=riscv64 -code-model=medium -relocation-model=pic -o /dev/null %s
; RUN: llc -mtriple=riscv64 -code-model=small -relocation-model=pic -o /dev/null %s

; The position-independent large code model.
;
; A pool entry holds a displacement from its own address rather than an
; address, which is a link-time constant and so needs no dynamic relocation:
; the pool stays read-only and within auipc range of the code. Today's absolute
; pool cannot be linked into a shared object at all, failing with "relocation
; R_RISCV_64 cannot be used against symbol".
;
; A non-preemptible symbol's displacement points at the symbol itself. A
; preemptible one's distance is not known until load time, so it is reached
; through a writable slot in .data.rel.ro that holds the address and takes the
; dynamic relocation, exactly as a GOT entry does. Those slots form one table
; per function, bootstrapped once, so each additional symbol costs a single
; load rather than its own pool entry and sequence.

@e1 = external global i32
@e2 = external global i32
@local = internal global i32 7

define i32 @two_preemptible() {
; One pool entry for the whole function: the displacement to its table.
; CHECK-LABEL: .LCPI0_0:
; CHECK-NEXT:  [[E:.Ltmp[0-9]+]]:
; CHECK-NEXT:    .quad .Lrvlp_tbl.two_preemptible-[[E]]
;
; CHECK-LABEL: two_preemptible:
; Bootstrap the table base once ...
; CHECK:         auipc [[B:a[0-9]+]], %pcrel_hi(.LCPI0_0)
; CHECK-NEXT:    addi [[B]], [[B]], %pcrel_lo({{.*}})
; CHECK-NEXT:    ld [[D:a[0-9]+]], 0([[B]])
; CHECK-NEXT:    add [[B]], [[B]], [[D]]
; ... then one load per symbol, at its slot offset.
; CHECK-DAG:     ld {{a[0-9]+}}, 0([[B]])
; CHECK-DAG:     ld {{a[0-9]+}}, 8([[B]])
;
; The table is writable, so it goes in .data.rel.ro rather than beside the
; code, and is emitted with the function that owns it. Slots are allocated in
; the order lowering first sees each symbol, which need not be source order.
; CHECK:         .section .data.rel.ro
; CHECK:       .Lrvlp_tbl.two_preemptible:
; CHECK-DAG:     .quad e1
; CHECK-DAG:     .quad e2
  %a = load i32, ptr @e1
  %b = load i32, ptr @e2
  %r = add i32 %a, %b
  ret i32 %r
}

define i32 @load_local() {
; A local symbol needs no slot: the displacement names it directly, and there
; is no dynamic relocation and no table entry.
; CHECK-LABEL: .LCPI1_0:
; CHECK-NEXT:  [[EL:.Ltmp[0-9]+]]:
; CHECK-NEXT:    .quad local-[[EL]]
;
; CHECK-LABEL: load_local:
; CHECK:         auipc [[R:a[0-9]+]], %pcrel_hi(.LCPI1_0)
; CHECK-NEXT:    addi [[R]], [[R]], %pcrel_lo({{.*}})
; CHECK-NEXT:    ld [[D:a[0-9]+]], 0([[R]])
; CHECK-NEXT:    add [[R]], [[R]], [[D]]
; CHECK-NEXT:    lw a0, 0([[R]])
  %v = load i32, ptr @local
  ret i32 %v
}

; A local symbol never gets a slot, so no table is emitted for a function that
; only uses local symbols.
; CHECK-NOT:   .Lrvlp_tbl.load_local
