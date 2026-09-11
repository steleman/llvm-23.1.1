# AArch64 large position-independent code model — patch series

  - 0001 MC        :gotoff_gN: specifiers and ELF relocations
  - 0002 lld       MOVW GOTOFF + MOVW GOTTPREL relocations
  - 0003 codegen   the code model itself (SelectionDAG + GlobalISel)
  - 0004 driver    accept -mcmodel=large with PIC on ELF

  [RFC-AArch64-Large-PIC](RFC-AArch64-Large-PIC.md):  RFC draft for discussion

## Applying

  git am --keep-non-patch 000[1-4]*.patch

## Patch contents

Patches 1 and 2 implement relocations AAELF64 already specifies and stand on
their own. Patches 3 and 4 depend on the ABI question raised in the RFC.

