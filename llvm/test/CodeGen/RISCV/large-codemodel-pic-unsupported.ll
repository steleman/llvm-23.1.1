; RUN: not llc -mtriple=riscv64 -code-model=large -relocation-model=pic \
; RUN:   -o /dev/null %s 2>&1 | FileCheck %s
; The check is in the target machine, so it does not depend on the selector.
; RUN: not llc -mtriple=riscv64 -code-model=large -relocation-model=pic \
; RUN:   -O0 -global-isel -o /dev/null %s 2>&1 | FileCheck %s

; The large code model puts absolute addresses in a literal pool emitted into
; .text. Under PIC those entries would need dynamic relocations, which cannot
; live in .text, and a writable section may be beyond the 2GiB that reaching
; the pool with auipc allows. The psABI disallows the combination.
;
; Without this diagnostic the request is silently ignored: lowering returns
; from the position-independent path in getAddr before the code model is
; consulted, emitting the same +/-2GiB sequences as the medium model.

; CHECK: LLVM ERROR: the large code model is not supported with position-independent code

; Combinations that must keep working. dynamic-no-pic in particular is not
; position independent, so it still reaches the code model and must not be
; caught by the check above.
; RUN: llc -mtriple=riscv64 -code-model=large -o /dev/null %s
; RUN: llc -mtriple=riscv64 -code-model=large -relocation-model=dynamic-no-pic -o /dev/null %s
; RUN: llc -mtriple=riscv64 -code-model=medium -relocation-model=pic -o /dev/null %s
; RUN: llc -mtriple=riscv64 -code-model=small -relocation-model=pic -o /dev/null %s
; RUN: llc -mtriple=riscv32 -code-model=large -o /dev/null %s

@g = external global i32

define i32 @load_global() {
  %v = load i32, ptr @g
  ret i32 %v
}
