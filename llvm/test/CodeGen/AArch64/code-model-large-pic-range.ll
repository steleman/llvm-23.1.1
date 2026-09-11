; RUN: llc -mtriple=aarch64-linux-gnu -code-model=large -relocation-model=pic \
; RUN:   -aarch64-min-jump-table-entries=4 -o - %s | FileCheck %s
; RUN: llc -mtriple=aarch64-linux-gnu -code-model=large -relocation-model=pic \
; RUN:   -aarch64-min-jump-table-entries=4 -O0 -global-isel -o - %s | FileCheck %s
; RUN: llc -mtriple=aarch64-linux-gnu -code-model=large -relocation-model=pic \
; RUN:   -aarch64-min-jump-table-entries=4 -O0 -global-isel=false -fast-isel \
; RUN:   -o - %s | FileCheck %s

; The whole point of the large code model is to escape ADRP's +/-4GB reach, so
; under -code-model=large with PIC no ADRP may be emitted for any kind of
; symbol. Emitting one is not a cosmetic difference: it silently reintroduces
; the range limit and fails at link time only once the image grows past 4GB.
;
; All three instruction selectors are covered. SelectionDAG and GlobalISel each
; implement the full-range sequences; FastISel has no large-PIC support and
; instead declines (materializeGV returns an invalid register), falling back to
; SelectionDAG, which is why it satisfies the same assertion.
;
; This is deliberately kept as a separate, hand-written file. Adding the check
; to code-model-large-pic.ll does not work, because update_llc_test_checks.py
; takes over every prefix it finds there and would replace this assertion with
; generated per-function checks.

; Matched as a whitespace-delimited mnemonic so the assertion cannot be
; satisfied or defeated by the string turning up inside a symbol or directive.
; CHECK-NOT: {{[ \t]adrp[ \t]}}

@preemptible = external global i32
@local = dso_local global i32 0

declare void @g0()
declare void @g1()
declare void @g2()
declare void @g3()
declare void @g4()

define i32 @global_preemptible() {
  %v = load i32, ptr @preemptible
  ret i32 %v
}

define i32 @global_local() {
  %v = load i32, ptr @local
  ret i32 %v
}

define double @constant_pool(double %x) {
  %r = fadd double %x, 3.14159265358979
  ret double %r
}

define void @jump_table(i32 %x) {
entry:
  switch i32 %x, label %def [ i32 0, label %c0
                              i32 1, label %c1
                              i32 2, label %c2
                              i32 3, label %c3
                              i32 4, label %c4 ]
c0:  tail call void @g0() ret void
c1:  tail call void @g1() ret void
c2:  tail call void @g2() ret void
c3:  tail call void @g3() ret void
c4:  tail call void @g4() ret void
def: ret void
}

define ptr @block_address() {
  ret ptr blockaddress(@block_address_target, %there)
}

define void @block_address_target(i1 %c) {
  br i1 %c, label %there, label %here
here:
  ret void
there:
  ret void
}
