; RUN: llc -mtriple=riscv64 --code-model=large < %s \
; RUN:     | FileCheck %s --check-prefix=RV64
; RUN: llc -mtriple=riscv64 --code-model=large -relocation-model=pic \
; RUN:     -riscv-large-pic < %s | FileCheck %s --check-prefix=RV64
; RUN: llc -mtriple=riscv64be --code-model=large < %s \
; RUN:     | FileCheck %s --check-prefix=RV64
; RUN: llc -mtriple=riscv32 --code-model=large < %s \
; RUN:     | FileCheck %s --check-prefix=RV32
; RUN: llc -mtriple=riscv64 --code-model=large -filetype=obj < %s \
; RUN:     | llvm-readobj -r - | FileCheck %s --check-prefix=RELOC

;; The large code model makes no assumptions about the distance between code
;; and data, so on RV64 the personality, LSDA and type table pointers are
;; 8-byte PC-relative values, as are the FDE initial locations.  There is no
;; 64-bit PC-relative data relocation, so they are ADD64/SUB64 pairs.  RV32
;; keeps the 4-byte encodings.

declare void @throw_exception()

declare i32 @__gxx_personality_v0(...)

declare ptr @__cxa_begin_catch(ptr)

declare void @__cxa_end_catch()

; RV64-LABEL: test1:
; RV64: .cfi_startproc
; PersonalityEncoding = DW_EH_PE_indirect | DW_EH_PE_pcrel | DW_EH_PE_sdata8
; RV64-NEXT: .cfi_personality 156, DW.ref.__gxx_personality_v0
; LSDAEncoding = DW_EH_PE_pcrel | DW_EH_PE_sdata8
; RV64-NEXT: .cfi_lsda 28, .Lexception0
; RV64-LABEL: GCC_except_table0:
; RV64: .byte 156 # @TType Encoding = indirect pcrel sdata8

; RV32-LABEL: test1:
; RV32: .cfi_personality 155, DW.ref.__gxx_personality_v0
; RV32-NEXT: .cfi_lsda 27, .Lexception0
; RV32-LABEL: GCC_except_table0:
; RV32: .byte 155 # @TType Encoding = indirect pcrel sdata4

; RELOC:      Section ({{.*}}) .rela.eh_frame {
; RELOC-NEXT:   R_RISCV_ADD64 DW.ref.__gxx_personality_v0 0x0
; RELOC-NEXT:   R_RISCV_SUB64 .L0 0x0
; RELOC-NEXT:   R_RISCV_ADD64 .L0 0x0
; RELOC-NEXT:   R_RISCV_SUB64 .L0 0x0
; RELOC-NEXT:   R_RISCV_ADD64 .L0 0x0
; RELOC-NEXT:   R_RISCV_SUB64 .L0 0x0
; RELOC-NEXT: }
; RELOC-NOT:  R_RISCV_32_PCREL

define void @test1() personality ptr @__gxx_personality_v0 {
entry:
  invoke void @throw_exception() to label %try.cont unwind label %lpad

lpad:
  %0 = landingpad { ptr, i32 }
          catch ptr null
  %1 = extractvalue { ptr, i32 } %0, 0
  %2 = tail call ptr @__cxa_begin_catch(ptr %1)
  tail call void @__cxa_end_catch()
  br label %try.cont

try.cont:
  ret void
}
