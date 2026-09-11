; RUN: llc -mtriple=aarch64-linux-gnu -code-model=large -relocation-model=pic \
; RUN:   -o - %s | FileCheck %s
; RUN: llc -mtriple=aarch64-linux-gnu -code-model=large -relocation-model=pic \
; RUN:   -O0 -global-isel -o - %s | FileCheck %s

; Two TLS models work under the large PIC code model.
;
; Local-exec needs nothing special: its TPREL sequence is computed off the
; thread pointer and never uses ADRP. Its 24-bit reach bounds the TLS block,
; not the image, which is the same limit the small code model has.
;
; Initial-exec uses the MOVZ/MOVK form of GOTTPREL to build the offset of the
; symbol's GOT entry from the GOT base, then indexes the GOT base with it. Only
; two chunks are defined by the ABI, so the GOT is bounded at 4GB; the image as
; a whole is not.

@le = dso_local thread_local(localexec) global i32 0
@ie = external thread_local(initialexec) global i32

define i32 @local_exec() {
; CHECK-LABEL: local_exec:
; CHECK:         mrs [[TP:x[0-9]+]], TPIDR_EL0
; CHECK:         add {{x[0-9]+}}, [[TP]], :tprel_hi12:.Lle$local
; CHECK:         add {{x[0-9]+}}, {{x[0-9]+}}, :tprel_lo12_nc:.Lle$local
  %v = load i32, ptr @le
  ret i32 %v
}

define i32 @initial_exec() {
; The two selectors schedule the second gottprel chunk differently relative to
; the GOT base computation, so these are order-independent.
; CHECK-LABEL: initial_exec:
; CHECK-DAG:     movz {{x[0-9]+}}, #:gottprel_g1:ie
; CHECK-DAG:     movk {{x[0-9]+}}, #:gottprel_g0_nc:ie
; CHECK-DAG:     adr {{x[0-9]+}}, {{.Ltmp[0-9]+}}
; CHECK-DAG:     movz x17, #:prel_g3:_GLOBAL_OFFSET_TABLE_+4
; CHECK-DAG:     movk x17, #:prel_g0_nc:_GLOBAL_OFFSET_TABLE_+16
; The GOT is indexed by a register, not a fixed offset, and the thread pointer
; is added to what comes back.
; CHECK:         ldr {{x[0-9]+}}, [{{x[0-9]+}}, {{x[0-9]+}}]
; CHECK:         mrs {{x[0-9]+}}, TPIDR_EL0
; No ADRP anywhere: that reach limit is what this code model exists to escape.
; CHECK-NOT:     {{[ \t]adrp[ \t]}}
  %v = load i32, ptr @ie
  ret i32 %v
}
