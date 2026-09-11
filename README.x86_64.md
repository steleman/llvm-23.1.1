# x86-64 large code model: general-dynamic TLS — single patch

# Applying

  git am --keep-non-patch 0001-*.patch

--keep-non-patch preserves the "[X86]" component tag, which plain git am
strips along with the "[PATCH]" prefix.

Unlike the AArch64 and RISC-V work this involves no ABI question: the sequence
is the one GCC already emits for -mcmodel=large, using relocations LLVM's MC
layer already supports. It is a plain bug fix, not a proposal, and needs no
RFC or flag.

# Scope note

Only general-dynamic changes. Initial-exec keeps the 32-bit gottpoff form
because GCC does too — that is an ABI-level property, not an LLVM gap — and
LLVM's local-exec is already more conservative than GCC's.

