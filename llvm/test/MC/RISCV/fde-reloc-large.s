# RUN: llvm-mc -filetype=obj -triple riscv64 -large-code-model -mattr=+relax < %s \
# RUN:     | llvm-readobj -r -x .eh_frame - | FileCheck %s
# RUN: llvm-mc -filetype=obj -triple riscv64 -large-code-model -mattr=-relax < %s \
# RUN:     | llvm-readobj -r -x .eh_frame - | FileCheck %s

# With the large code model, the FDE initial location is an 8-byte
# PC-relative value (DW_EH_PE_pcrel | DW_EH_PE_sdata8).  There is no 64-bit
# PC-relative data relocation, so it is always an ADD64/SUB64 pair.

func:
	.cfi_startproc
  ret
	.cfi_endproc

# CHECK:   Section (4) .rela.eh_frame {
# CHECK-NEXT:   0x1C R_RISCV_ADD64 .L0 0x0
# CHECK-NEXT:   0x1C R_RISCV_SUB64 .L0 0x0
# CHECK-NEXT: }
# CHECK:      Hex dump of section '.eh_frame':
# CHECK-NEXT: 0x00000000 10000000 00000000 017a5200 01780101
# CHECK-NEXT: 0x00000010 1c0c0200 18000000 18000000 00000000
#                        ^ FDE encoding
# CHECK-NEXT: 0x00000020 00000000 04000000 00000000 00000000
#                                 ^ address_range
