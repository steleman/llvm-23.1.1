; RUN: llc -mtriple=aarch64-linux-gnu -code-model=large -relocation-model=pic \
; RUN:   -O0 -global-isel -global-isel-abort=1 -aarch64-min-jump-table-entries=4 \
; RUN:   -o - %s | FileCheck %s

; GlobalISel is the default selector at -O0 on AArch64, so it needs its own
; large-PIC support rather than relying on the SelectionDAG path.
; -global-isel-abort=1 makes a silent fallback to SelectionDAG a hard error, so
; this also asserts that GlobalISel really is selecting these itself.

@preemptible = external global i32
@local = dso_local global i32 0

define i32 @got_access() {
; CHECK-LABEL: got_access:
; CHECK:         movz x{{[0-9]+}}, #:gotoff_g0_nc:preemptible
; CHECK:         movk x{{[0-9]+}}, #:gotoff_g1_nc:preemptible
; CHECK:         movk x{{[0-9]+}}, #:gotoff_g2_nc:preemptible
; CHECK:         movk x{{[0-9]+}}, #:gotoff_g3:preemptible
; CHECK:         adr x{{[0-9]+}}, [[PC:.Ltmp[0-9]+]]
; CHECK:         movz x17, #:prel_g3:_GLOBAL_OFFSET_TABLE_+4
; CHECK:         movk x17, #:prel_g2_nc:_GLOBAL_OFFSET_TABLE_+8
; CHECK:         movk x17, #:prel_g1_nc:_GLOBAL_OFFSET_TABLE_+12
; CHECK:         movk x17, #:prel_g0_nc:_GLOBAL_OFFSET_TABLE_+16
  %v = load i32, ptr @preemptible
  ret i32 %v
}

define i32 @direct_access() {
; CHECK-LABEL: direct_access:
; CHECK:         adr x{{[0-9]+}}, {{.Ltmp[0-9]+}}
; CHECK:         movz x17, #:prel_g3:.Llocal$local+4
; CHECK:         movk x17, #:prel_g2_nc:.Llocal$local+8
; CHECK:         movk x17, #:prel_g1_nc:.Llocal$local+12
; CHECK:         movk x17, #:prel_g0_nc:.Llocal$local+16
  %v = load i32, ptr @local
  ret i32 %v
}

define double @constant_pool(double %x) {
; CHECK-LABEL: constant_pool:
; CHECK:         adr x{{[0-9]+}}, {{.Ltmp[0-9]+}}
; CHECK:         movz x17, #:prel_g3:[[CP:.LCPI[0-9]+_[0-9]+]]+4
; CHECK:         movk x17, #:prel_g0_nc:[[CP]]+16
  %r = fadd double %x, 3.14159265358979
  ret double %r
}

define ptr @block_address() {
; CHECK-LABEL: block_address:
; CHECK:         adr x{{[0-9]+}}, {{.Ltmp[0-9]+}}
; CHECK:         movz x17, #:prel_g3:[[BA:.Ltmp[0-9]+]]+4
; CHECK:         movk x17, #:prel_g0_nc:[[BA]]+16
  ret ptr blockaddress(@block_address_target, %there)
}

define void @block_address_target(i1 %c) {
  br i1 %c, label %there, label %here
here:
  ret void
there:
  ret void
}

declare void @g0()
declare void @g1()
declare void @g2()
declare void @g3()
declare void @g4()

define void @jump_table(i32 %x) {
; CHECK-LABEL: jump_table:
; CHECK:         adr x{{[0-9]+}}, {{.Ltmp[0-9]+}}
; CHECK:         movz x17, #:prel_g3:[[JT:.LJTI[0-9]+_[0-9]+]]+4
; CHECK:         movk x17, #:prel_g0_nc:[[JT]]+16
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
