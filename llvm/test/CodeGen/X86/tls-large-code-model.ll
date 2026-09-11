; RUN: llc -mtriple=x86_64-unknown-linux-gnu -relocation-model=pic \
; RUN:   -code-model=large -o - %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -relocation-model=pic \
; RUN:   -code-model=small -o - %s | FileCheck %s --check-prefix=SMALL

; In the large code model __tls_get_addr may be more than 2GiB away, so the
; small model's 32-bit PC-relative call to the PLT cannot reach it. Compute the
; GOT base with a 64-bit displacement and call through a 64-bit PLTOFF, which
; is the sequence GCC emits for -mcmodel=large.
;
; The four instructions from the LEA onwards are byte-matched by the linker
; when it relaxes general-dynamic to initial-exec or local-exec, so the
; registers are fixed by the ABI: the PLTOFF value must be in RAX and the GOT
; base in RBX. Using other registers changes the encodings and the sequence
; length, and the link then fails with "TLS transition ... failed".

@gd = external thread_local global i32

define i32 @general_dynamic() {
; CHECK-LABEL: general_dynamic:
; CHECK:         pushq %rbx
; CHECK:       [[PB:.Ltmp[0-9]+]]:
; CHECK-NEXT:    leaq [[PB]](%rip), %rbx
; CHECK-NEXT:    movabsq $_GLOBAL_OFFSET_TABLE_-[[PB]], %r11
; CHECK-NEXT:    addq %r11, %rbx
; The ABI-fixed part: these four, in these registers.
; CHECK-NEXT:    leaq gd@TLSGD(%rip), %rdi
; CHECK-NEXT:    movabsq $__tls_get_addr@PLTOFF, %rax
; CHECK-NEXT:    addq %rbx, %rax
; CHECK-NEXT:    callq *%rax
; CHECK:         popq %rbx
;
; The small model keeps the 32-bit PC-relative call.
; SMALL-LABEL: general_dynamic:
; SMALL:         leaq gd@TLSGD(%rip), %rdi
; SMALL:         callq __tls_get_addr@PLT
; SMALL-NOT:     PLTOFF
  %v = load i32, ptr @gd
  ret i32 %v
}
