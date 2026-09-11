# RISC-V Position-Independent Large Code Model

  0001  diagnose -code-model=large with PIC instead of silently ignoring it
  0002  prototype the model behind -riscv-large-pic (non-preemptible symbols)
  0003  preemptible symbols, via a writable table in .data.rel.ro
  0004  anchor that table per function so the bootstrap is paid once

  [RISCV-DESIGN.md](RISCV-DESIGN.md):    design, alternatives, measurements, open questions

## Applying

  git am --keep-non-patch 000[1-4]*.patch

--keep-non-patch matters: without it git am strips every leading bracket group
from the subject, so "[RFC PATCH 1/4] [RISCV] Diagnose ..." loses its "[RISCV]"
component tag. Verified: the series applies cleanly onto the base commit and
the subjects survive intact.

## Status

- Patch 1 is a straightforward bug fix and is independent of the ABI question.

- Patches 2-4 are a proposal. The psABI currently says "Large code model is
disallowed to be used with PIC code model", so they are off by default and
objects built with them interoperate with nothing. They need
riscv-elf-psabi-doc#388 to move before they mean anything.

