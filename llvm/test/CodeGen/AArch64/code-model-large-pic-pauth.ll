; RUN: not llc -mtriple=aarch64-linux-gnu -mattr=+pauth -code-model=large \
; RUN:   -relocation-model=pic -o /dev/null %s 2>&1 | FileCheck %s
; RUN: not llc -mtriple=aarch64-linux-gnu -mattr=+pauth -code-model=large \
; RUN:   -relocation-model=pic -O0 -global-isel -o /dev/null %s 2>&1 | FileCheck %s

; A signed GOT entry would need R_AARCH64_AUTH_MOVW_GOTOFF_G*, which is not
; implemented. Both alternatives are wrong and must not be taken silently:
; the plain gotoff sequence drops the authentication, and LOADgotAUTH is
; ADRP-based so it cannot reach in this code model.

; CHECK: error: {{.*}}signed GOT is not supported with the large code model and PIC

@preemptible = external global i32

define i32 @f() {
  %v = load i32, ptr @preemptible
  ret i32 %v
}

!llvm.module.flags = !{!0}
!0 = !{i32 8, !"ptrauth-elf-got", i32 1}
