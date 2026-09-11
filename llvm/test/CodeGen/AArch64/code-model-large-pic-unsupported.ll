; RUN: not llc -mtriple=aarch64-linux-gnu -code-model=large -relocation-model=pic \
; RUN:   -o /dev/null %s 2>&1 | FileCheck %s --check-prefix=TLS
; RUN: not llc -mtriple=aarch64-linux-gnu -code-model=large -relocation-model=pic \
; RUN:   -O0 -global-isel -o /dev/null %s 2>&1 | FileCheck %s --check-prefix=TLS

; The dynamic TLS models need TLSDESC, whose only defined sequence is
; ADRP-based, so they cannot be reached in the large code model. Diagnose
; rather than silently emitting an ADRP that fails to reach at link time.

; TLS: error: {{.*}}the large code model only supports local-exec TLS, and initial-exec when building position-independent code

@gd = external thread_local global i32

define i32 @general_dynamic() {
  %v = load i32, ptr @gd
  ret i32 %v
}
