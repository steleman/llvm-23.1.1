// RUN: llvm-mc -triple=aarch64-none-linux-gnu -filetype=obj %s -o - | \
// RUN:   llvm-readobj -r - | FileCheck -check-prefix=OBJ %s
// RUN: llvm-mc -triple=aarch64-none-linux-gnu %s -o - | \
// RUN:   FileCheck -check-prefix=ASM %s
// RUN: not llvm-mc -triple=aarch64-none-linux-gnu_ilp32 -filetype=obj \
// RUN:   -o /dev/null %s 2>&1 | FileCheck -check-prefix=ILP32 %s

        movz x0, #:gotoff_g0:sym
        movk x0, #:gotoff_g0_nc:sym

        movz x1, #:gotoff_g1:sym
        movk x1, #:gotoff_g1_nc:sym

        movz x2, #:gotoff_g2:sym
        movk x2, #:gotoff_g2_nc:sym

        movz x3, #:gotoff_g3:sym

// ASM: movz x0, #:gotoff_g0:sym
// ASM: movk x0, #:gotoff_g0_nc:sym
// ASM: movz x1, #:gotoff_g1:sym
// ASM: movk x1, #:gotoff_g1_nc:sym
// ASM: movz x2, #:gotoff_g2:sym
// ASM: movk x2, #:gotoff_g2_nc:sym
// ASM: movz x3, #:gotoff_g3:sym

// OBJ:      Relocations [
// OBJ-NEXT:   Section {{.*}} .rela.text {
// OBJ-NEXT:     0x0  R_AARCH64_MOVW_GOTOFF_G0    sym 0x0
// OBJ-NEXT:     0x4  R_AARCH64_MOVW_GOTOFF_G0_NC sym 0x0
// OBJ-NEXT:     0x8  R_AARCH64_MOVW_GOTOFF_G1    sym 0x0
// OBJ-NEXT:     0xC  R_AARCH64_MOVW_GOTOFF_G1_NC sym 0x0
// OBJ-NEXT:     0x10 R_AARCH64_MOVW_GOTOFF_G2    sym 0x0
// OBJ-NEXT:     0x14 R_AARCH64_MOVW_GOTOFF_G2_NC sym 0x0
// OBJ-NEXT:     0x18 R_AARCH64_MOVW_GOTOFF_G3    sym 0x0
// OBJ-NEXT:   }
// OBJ-NEXT: ]

// ILP32: error: absolute MOV relocation is not supported in ILP32
