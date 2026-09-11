; RUN: llc -mtriple=aarch64-none-linux-gnu -aarch64-enable-atomic-cfg-tidy=0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -code-model=large -mtriple=aarch64-none-linux-gnu -aarch64-enable-atomic-cfg-tidy=0 -verify-machineinstrs < %s | FileCheck --check-prefix=CHECK-LARGE %s
; RUN: llc -code-model=large -relocation-model=pic -mtriple=aarch64-none-linux-gnu -aarch64-enable-atomic-cfg-tidy=0 < %s | FileCheck --check-prefix=CHECK-LARGE-PIC %s
; RUN: llc -code-model=tiny -mtriple=aarch64-none-elf -aarch64-enable-atomic-cfg-tidy=0 -verify-machineinstrs < %s | FileCheck --check-prefix=CHECK-TINY %s

@addr = global ptr null

define void @test_blockaddress() {
; CHECK-LABEL: test_blockaddress:
  store volatile ptr blockaddress(@test_blockaddress, %block), ptr @addr
  %val = load volatile ptr, ptr @addr
  indirectbr ptr %val, [label %block]
; CHECK: adrp [[DEST_HI:x[0-9]+]], [[DEST_LBL:.Ltmp[0-9]+]]
; CHECK: add [[DEST:x[0-9]+]], [[DEST_HI]], {{#?}}:lo12:[[DEST_LBL]]
; CHECK: str [[DEST]],
; CHECK: ldr [[NEWDEST:x[0-9]+]]
; CHECK: br [[NEWDEST]]

; CHECK-LARGE: movz [[ADDR_REG:x[0-9]+]], #:abs_g0_nc:[[DEST_LBL:.Ltmp[0-9]+]]
; CHECK-LARGE: movk [[ADDR_REG]], #:abs_g1_nc:[[DEST_LBL]]
; CHECK-LARGE: movk [[ADDR_REG]], #:abs_g2_nc:[[DEST_LBL]]
; CHECK-LARGE: movk [[ADDR_REG]], #:abs_g3:[[DEST_LBL]]
; CHECK-LARGE: str [[ADDR_REG]],
; CHECK-LARGE: ldr [[NEWDEST:x[0-9]+]]
; CHECK-LARGE: br [[NEWDEST]]

; The large PIC code model reaches the block address with a full-range
; PC-relative sequence; no ADRP appears, as its +/-4GB range is the limit the
; model exists to escape. The :prel_g3: chunk names the block label, which
; distinguishes it from the GOT base computation used to reach @addr.
; CHECK-LARGE-PIC-NOT: adrp
; CHECK-LARGE-PIC: adr [[PCREG:x[0-9]+]], {{.Ltmp[0-9]+}}
; CHECK-LARGE-PIC: movz x17, #:prel_g3:[[DEST_LBL:.Ltmp[0-9]+]]+4
; CHECK-LARGE-PIC: movk x17, #:prel_g2_nc:[[DEST_LBL]]+8
; CHECK-LARGE-PIC: movk x17, #:prel_g1_nc:[[DEST_LBL]]+12
; CHECK-LARGE-PIC: movk x17, #:prel_g0_nc:[[DEST_LBL]]+16
; CHECK-LARGE-PIC: add [[DEST:x[0-9]+]], [[PCREG]], x17
; CHECK-LARGE-PIC: str [[DEST]],
; CHECK-LARGE-PIC: ldr [[NEWDEST:x[0-9]+]]
; CHECK-LARGE-PIC: br [[NEWDEST]]

; CHECK-TINY: adr [[DEST:x[0-9]+]], {{.Ltmp[0-9]+}}
; CHECK-TINY: str [[DEST]],
; CHECK-TINY: ldr [[NEWDEST:x[0-9]+]]
; CHECK-TINY: br [[NEWDEST]]

block:
  ret void
}
