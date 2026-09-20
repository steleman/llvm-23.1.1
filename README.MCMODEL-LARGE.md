# Large code model work — LLVM 23.1.1

This directory holds LLVM and Clang work that completes the large code model
(`-mcmodel=large`) on AArch64, RISCV64 and x86-64. The focus is
position-independent code (`-fpic`/`-fPIC`), where upstream LLVM either
rejected the combination or silently fell back to ±2–4 GiB sequences.

The work is based on eleven commits on a branch named `mcmodel-large` in
`llvm-project-mcmodel-large/`. The branch is based directly on the `llvmorg-23.1.1`
release tag (`6dfe1677ab8d`).

As of 2026-09-19 all commits are merged and pushed to the `main` branch and to Github.

---

| Directory | Commits | Target | Kind |
|---|---|---|---|
| `mcmodel-large-pic-aarch64/` | `6252702ff097` `0f3239439e52` `1d05750dd65c` `923b6ce4c476` | AArch64 | Complete implementation; RFC (`RFC-aarch64-large-pic.md`) |
| `mcmodel-large-pic-riscv/` | `a0fc20f1045d` `b3b22127ba0b` `0d525ec45f7b` `59cd9ed34ad4` `ed825fc0ba39` `aa9320e2847e` | RISCV64 | Bug fix, then the model, then turning it on: `-mcmodel=large -fPIC` works from the driver; `DESIGN.md`, `POST-388.md` |
| `mcmodel-large-tls-x86_64/` | `78e24eb023c1` | x86-64 | Bug fix |
| `mcmodel-large-eh-riscv/` | `4fe0518a293f` | RISCV64 | 8-byte EH pointer encodings in the large model |
| `mcmodel-large-jt-riscv/` | `98677af3cb50` | RISCV64 | Bug fix: jump tables in the function's section under the large model |

The AArch64 series applies to `llvmorg-23.1.1`. The RISCV PIC series is based
on the last AArch64 commit, but its patch 0001 applies to the tag on its own.
The x86-64 patch applies to the tag independently. The RISCV EH patch sits on
top of `78e24eb023c1`. The RISCV jump-table patch sits on top of
`4fe0518a293f` and also applies to the tag on its own, except for two test RUN
lines that use `-riscv-large-pic`. **That option no longer exists** as of
`ed825fc0ba39`, which made the model the default; those two RUN lines need the
option dropped when the jump-table patch is rebased past it.

Companion series, which implement the same models so objects interoperate:

| Toolchain | Location |
|---|---|
| GCC 16.2.0 | `/src/steleman/programming/gcc-mcmodel-large/16.2.0/gcc16-mcmodel-large-pic` |
| GCC 16.0.1 | `/src/steleman/programming/gcc-mcmodel-large/16.0.1/gcc16-mcmodel-large-pic` |
| GNU binutils 2.46.1 | `/src/steleman/programming/binutils-mcmodel-large/2.46.1/binutils-mcmodel-large-pic` |

---

GCC 16.2.0 and GNU Binutils 2.46.1 with ABI compatible changes will be committed
to my Github very shortly.

---

## Where upstream stood at `llvmorg-23.1.1`

| Target | `-mcmodel=large` with PIC |
|---|---|
| AArch64 | The driver rejected it. The backend, used directly, fell through to the small model's ADRP+ADD / ADRP+LDR, silently reintroducing the ±4 GiB reach. |
| RISCV64 | The driver rejected it. In the backend, `RISCVTargetLowering::getAddr` returned from its `isPositionIndependent()` branch before consulting the code model: small, medium and large under PIC produced byte-identical ±2 GiB output. Separately, the position-dependent large model put jump tables in `.rodata` behind a ±2 GiB `auipc` (fixed by `98677af3cb50`). |
| x86-64 | A working large PIC model (`leaq`/`movabsq` GOT base, `@GOT` offsets). The one gap: general-dynamic TLS used the small model's 32-bit `call __tls_get_addr@PLT`. |

The driver gate for all three is `tools::addMCModel` in
`clang/lib/Driver/ToolChains/CommonArgs.cpp`.

---

## AArch64 large PIC (`mcmodel-large-pic-aarch64/`)

AAELF64 allocates the `R_AARCH64_MOVW_GOTOFF_G*` relocations but defines no
large PIC code model, so these sequences were a design decision. GCC 16 and
binutils now implement exactly the same sequences, which makes them a de facto
shared convention. See the RFC for the ABI question.

The RFC (`RFC-aarch64-large-pic.md`) is a Discourse draft. It presents the GCC
and binutils work as companion series not yet submitted upstream, with no
local paths or GCC version numbers. It was updated on 2026-09-16 for that
work (two compilers and three linkers, the MOVK rules a specification must pin
down, the 24/24 and 5 GiB results) and on 2026-09-17 after the GCC 16.2.0
retest, which it calls "a later GCC release": the tests pass again, and the
Compatibility section records the one remaining difference, FDE initial
locations (see [Compatibility: AArch64](#aarch64) below). The series README
(`mcmodel-large-pic-aarch64/README`) lists what each update changed.

### 0001 — MC: `:gotoff_g0:` … `:gotoff_g3:` specifiers

- Adds specifiers and assembler syntax for `R_AARCH64_MOVW_GOTOFF_G0..G3`
  (0x12c–0x132), which compute `G(GDAT(S)) - GOT` in 16-bit chunks:
  `:gotoff_g0:` `:gotoff_g0_nc:` `:gotoff_g1:` `:gotoff_g1_nc:` `:gotoff_g2:`
  `:gotoff_g2_nc:` `:gotoff_g3:`.
- They reuse the `S_GOT` symbol-location bit combined with a granule, an
  otherwise unused encoding, and are wired through the per-granule operand
  predicates in the parser.
- The checked variants are MOV[NZ]-class relocations, so they join the signed
  fixups handled by `fixMOVZ`, alongside TPREL and GOTTPREL.
- ILP32 rejects them, because there are no `R_AARCH64_P32_MOVW_GOTOFF_*`
  relocations.
- The spellings follow the relocation names and the `:prel_gN:`/`:gottprel_gN:`
  convention. GNU as with the binutils series accepts identical spellings.

### 0002 — lld: MOVW GOTOFF and MOVW GOTTPREL

- `MOVW_GOTOFF_G0..G3` map to the existing `R_GOT_OFF` expression.
  `_GLOBAL_OFFSET_TABLE_` is the start of `.got` on AArch64
  (`gotBaseSymInGotPlt` is false). They share the signed MOVW application path
  (`writeSMovWImm`), which picks MOVZ/MOVN by sign but leaves a MOVK a MOVK.
- `TLSIE_MOVW_GOTTPREL_G1/_G0_NC`, the MOVZ/MOVK form of initial-exec, are
  supported, with **IE→LE relaxation disabled** (`handleTlsIe<false>`). The
  relaxation writes the thread-pointer offset into the field the GOT offset
  occupied. That is only valid when the consuming load is itself relocated,
  but here it is a plain register-offset `LDR` with no relocation. Relaxing
  would drop the GOT entry and leave the `LDR` dereferencing a TP offset.
  `lld/test/ELF/aarch64-tlsie-movw-gottprel.s` pins this.

### 0003 — Codegen: the code model

`AArch64Subtarget::isLargePIC()` gates everything. Both SelectionDAG
(`AArch64TargetLowering`) and GlobalISel
(`AArch64InstructionSelector::selectLargePICGlobalValue`) implement it.

The GOT base is computed PC-relatively with unlimited range, the same shape as
x86-64 large PIC:

```asm
.Lpc:
  adr  xD, .Lpc
  movz x17, #:prel_g3:_GLOBAL_OFFSET_TABLE_+4
  movk x17, #:prel_g2_nc:_GLOBAL_OFFSET_TABLE_+8
  movk x17, #:prel_g1_nc:_GLOBAL_OFFSET_TABLE_+12
  movk x17, #:prel_g0_nc:_GLOBAL_OFFSET_TABLE_+16
  add  xD, xD, x17
```

- This is the `MOVaddrPREL` pseudo (`AArch64ISD::AddrPRELLarge`), expanded in
  `AArch64AsmPrinter::LowerMOVaddrPREL`. `x17` is the scratch, so the
  destination class is `GPR64noip`.
- `MOVW_PREL` resolves as `S + A - P` against its own instruction, so the
  addends +4…+16 make each chunk a slice of the same value. Getting them wrong
  is the easiest way to break the model. `lld/test/ELF/aarch64-large-pic-got-base.s`
  pins the arithmetic.

Symbol access:

| Symbol | Path | Sequence |
|---|---|---|
| Preemptible | `getGOTLargePIC` | `MO_GOT` plus a granule flag lowers to `:gotoff_gN:`, so `WrapperLarge` builds the 64-bit offset low chunk first (`movz #:gotoff_g0_nc:` … `movk #:gotoff_g3:`); add the GOT base and load. The GOT base is a separate node, so accesses in one function share it. |
| Non-preemptible, jump tables, constant pools, block addresses | `getAddrLargePIC` | `MOVaddrPREL` directly, no GOT |

- Jump table dispatch (`LowerJumpTableDest`) and ELF calls (`BL`/`CALL26`,
  which the linker range-extends) need no change.
- **TLS:** local-exec works unchanged. Initial-exec uses
  `movz #:gottprel_g1:` / `movk #:gottprel_g0_nc:` indexing the GOT base.
  AAELF64 defines only two GOTTPREL chunks, so the GOT is limited to 4 GiB.
  General-/local-dynamic need TLSDESC, whose only defined sequence is
  ADRP-based, so they emit a `DiagnosticInfoUnsupported` error from both
  selectors. The previous `report_fatal_error` becomes this proper diagnostic.
- **Pointer authentication:** a signed GOT would need
  `R_AARCH64_AUTH_MOVW_GOTOFF_G*`, which nothing implements. It is diagnosed
  rather than compiled, because both fallbacks are wrong: plain gotoff silently
  drops authentication, and `LOADgotAUTH` cannot reach.
- **FastISel** needs nothing: `materializeGV` already declines when
  `!useSmallAddressing()` and falls back to SelectionDAG (checked with
  `-fast-isel-abort=1`).
- The invariant is **no ADRP under large PIC**, asserted for all three
  selectors in `llvm/test/CodeGen/AArch64/code-model-large-pic-range.ll`. Keep
  that test hand-written: `update_llc_test_checks.py` would replace its bare
  `CHECK-NOT`s.

Two traps found during development:

- In GlobalISel, `I.setDesc()` does not add the descriptor's implicit
  operands. `MOVaddrPREL` clobbers x17 via `Defs = [X17]`, so without
  `I.addImplicitDefUseOperands(MF)` the register allocator cannot see the
  clobber. The problem is only visible in MIR.
- `MachineOperand::getOffset()` asserts on a jump-table index, so code walking
  `MOVaddrPREL` operands must guard with `MO.isJTI()`.

### 0004 — Driver

- `addMCModel` accepts `-mcmodel=large` with PIC on AArch64 ELF.
- COFF keeps the error (`aarch64-w64-mingw32` accepts `-fpic`). MachO was
  already exempt.
- `-fptrauth-elf-got` combined with large PIC is rejected in the driver.
  Signed GOT is opt-in only (the `pauthtest` ABI doesn't imply it), so testing
  the flag covers every case (`clang/test/Driver/mcmodel.c`).

---

## RISCV64 large PIC (`mcmodel-large-pic-riscv/`)

The RISCV large model loads absolute addresses from a constant pool that
`RISCVELFTargetObjectFile::getSectionForConstant` forces into `.text`, within
`auipc` range. Under PIC those entries need dynamic relocations, which cannot
live in `.text`, and `.data.rel.ro` may be more than 2 GiB away. The psABI
(riscv-elf-psabi-doc#388) specifies only the position-dependent large model and
states that "Large code model is disallowed to be used with PIC code model".
Patches 0002–0004 are therefore a proposal. They were developed behind the
hidden option `-riscv-large-pic`; patches 0005–0006 take them as normative and
turn the feature on, so the option is gone and `-mcmodel=large -fPIC` works
from the driver. What has not changed is the psABI: these sequences are still
unratified, and objects built with them interoperate only with a toolchain
using the same ones. `POST-388.md` is a draft follow-up for that psABI thread.

### 0001 — Diagnose large + PIC (bug fix)

- `-code-model=large` with `Reloc::PIC_` is diagnosed in the target machine,
  instead of being silently compiled as medium.
- It tests `Reloc::PIC_`, not "not static": `dynamic-no-pic` still gets
  correct large-model sequences.
- RV32 large is left alone. The driver rejects it, but
  `CodeGen/RISCV/tail-calls.ll` depends on the backend accepting it.
- Independent of the ABI question.

### 0002 — Prototype, non-preemptible symbols

The pool entry holds the displacement from itself to the symbol, a label
difference emitted as `R_RISCV_ADD64`/`SUB64` and resolved by the static
linker:

```asm
.LCPI0_0:
.Ltmp0:
  .quad local-.Ltmp0
    auipc a0, %pcrel_hi(.LCPI0_0)
    addi  a0, a0, %pcrel_lo(.Lpcrel_hi0)   # a0 = &entry
    ld    a1, 0(a0)                        # a1 = local - &entry
    add   a0, a0, a1                       # a0 = &local
```

- The shared object has no dynamic relocations and a read-only `.text`.
- `LowerCall` materializes call targets through the same pool.

### 0003 — Preemptible symbols

- A preemptible symbol needs a writable slot in `.data.rel.ro`, and the
  machine constant pool cannot supply one. `AsmPrinter::emitConstantPool` does
  choose a section per entry, but it passes a null `Constant` for
  `MachineConstantPoolValue`s, and every flavor reports `ReadOnlyWithRel`.
  There is nothing to tell the two kinds of entry apart.
- The AsmPrinter records each target while emitting the entry that references
  it, and writes the slots from `emitEndOfAsmFile`. Slots are keyed on
  `MCSymbol`, so libcall targets work too.
- The earlier bool became a three-state `Form` enum. `equals()` and the CSE id
  must discriminate all three forms, or entries holding different values would
  be merged.

### 0004 — Anchor the table per function

Each function gets one indirection table, `.Lrvlp_tbl.<fn>`, in
`.data.rel.ro`. One pool entry holds the displacement to it, and each symbol is
then a single load:

```asm
.LCPI0_0:
.Ltmp0:
  .quad .Lrvlp_tbl.f-.Ltmp0
    auipc a0, %pcrel_hi(.LCPI0_0)   # bootstrap, once per function
    addi  a0, a0, %pcrel_lo(...)
    ld    a1, 0(a0)
    add   a0, a0, a1                # a0 = table base
    ld    a1, 0(a0)                 # one load per symbol
    ld    a2, 8(a0)
```

- Slot indices are allocated during lowering, in DAG order rather than source
  order, and held in `RISCVMachineFunctionInfo`. The table is emitted from
  `emitFunctionBodyEnd`.
- Measured instructions for N preemptible globals at `-O2`:

  | N | medium PIC | large PIC (anchored) |
  |---|---|---|
  | 1 | 4 | 7 |
  | 2 | 8 | 10 |
  | 4 | 16 | 16 |
  | 8 | 32 | 28 |

  The model breaks even at four symbols. The bootstrap is loop-invariant and
  hoists.
- TLS keeps the GOT-relative ±2 GiB sequences.

### 0005 — Make the model the default

Takes the sequences above as normative and removes the scaffolding:

- the `-riscv-large-pic` option and its accessor, and the
  `RISCVTargetMachine.h` declaration;
- `getEffectiveRISCVCodeModel`, whose only job was to reject large with PIC.
  The constructor goes back to `getEffectiveCodeModel` directly;
- the option tests in `RISCVTargetLowering::getAddr` and in call lowering.

`RISCVELFTargetObjectFile::getSectionForConstant` keeps the pool in `.text`,
but its comment is rewritten: it cited the old restriction as the reason.
`.text` is still right, for a different reason — the entries now hold
displacements, which are link-time constants needing no dynamic relocation.
The slots that do need one are emitted separately into `.data.rel.ro`.

`large-codemodel-pic-unsupported.ll` tested the diagnostic and is deleted; its
coverage of the neighbouring combinations that must keep working (large static,
large with `dynamic-no-pic`, medium and small with PIC) moves into
`large-codemodel-pic.ll`.

### 0006 — Driver

- `addMCModel` stops rejecting `-mcmodel=large` with PIC on RISCV.
- The model stays RV64-only, matching the psABI and the existing
  `Triple.isRISCV64()` guard; `clang/test/Driver/riscv-mcmodel.c` now covers
  that for the PIC case too.
- `__riscv_cmodel_large` already follows the code model alone, so it needed no
  change.

Order matters: 0006 must not land before 0005, or the driver accepts a flag
combination the backend still compiles as medium.

Using it from Clang, which is now the whole story:

```sh
clang --target=riscv64-linux-gnu -march=rv64gc -mabi=lp64d -O2 -fPIC \
      -mcmodel=large -c -o f.o f.c
```

---

## RISCV64 EH encodings (`mcmodel-large-eh-riscv/`, `4fe0518a293f`)

The large model makes no assumption about the distance between code and
`.eh_frame`, but RISCV used 4-byte PC-relative EH pointers regardless.
AArch64 and x86-64 already used 8-byte ones for `CodeModel::Large`. For RV64
with `CodeModel::Large` only (RV32, small and medium are unchanged):

| Field | Before | After | Where |
|---|---|---|---|
| FDE initial location | 0x1b | 0x1c pcrel\|sdata8 | `MCObjectFileInfo::initELFMCObjectFileInfo` (riscv64/riscv64be join the aarch64/x86_64 large case) |
| LSDA | 0x1b | 0x1c | `TargetLoweringObjectFileELF::Initialize` |
| Personality, type table | 0x9b | 0x9c indirect\|pcrel\|sdata8 | `TargetLoweringObjectFileELF::Initialize` |

- `RISCVMCAsmInfo::getExprForFDESymbol` used to force `R_RISCV_32_PCREL` and
  assert sdata4. There is no 64-bit PC-relative data relocation, so for sdata8
  it returns the plain symbol difference, which `RISCVAsmBackend::addReloc`
  emits as an `ADD64`/`SUB64` pair.
- `llvm-mc` selects sdata8 FDEs only with `-large-code-model`. Textual `.cfi_*`
  directives assembled without that option keep sdata4.
- Why the 4-byte form was unsafe, not just range-limited: with code 3 GiB
  away, unpatched ld.bfd silently wrapped FDE pointers (an FDE for
  `0xc0023200` decoded as `0xffffffffc0023200`), while lld rejected them.
- Tests: `llvm/test/CodeGen/RISCV/dwarf-eh-large.ll` (hand-written) and
  `llvm/test/MC/RISCV/fde-reloc-large.s`; both fail without the change.

---

## RISCV64 jump tables (`mcmodel-large-jt-riscv/`, `98677af3cb50`)

Under `-code-model=large`, `RISCVTargetLowering::getAddr` lowers a jump table
to `PseudoLLA` (`auipc`/`addi`, ±2 GiB), but ELF put jump tables in `.rodata`,
which the large model allows to be further away. Links with data more than
2 GiB from the code failed with "relocation R_RISCV_PCREL_HI20 out of range …
references '.LJTI…'". This affected the position-dependent large model that
the psABI specifies, as well as the PIC model.

- `RISCVELFTargetObjectFile::shouldPutJumpTableInFunctionSection` now returns
  true for `CodeModel::Large`, so the table follows the function in its own
  section, as large-model constant pools already do (`getSectionForConstant`).
  GCC does the same (`JUMP_TABLES_IN_TEXT_SECTION` for `CM_LARGE`).
- Entry encodings are unchanged (`.quad .LBBn` static, `.word .LBBn-.LJTIn`
  PIC). Other code models keep tables in `.rodata`.
- In the PIC model the function's `.data.rel.ro` indirection table is
  emitted first and the AsmPrinter switches back to the function's section, so
  the jump table still lands next to the code, with or without
  `-function-sections`.
- Why it first looked `-O0`-only: at `-O2` the switch in the test that found it
  became a lookup table (`.Lswitch.table.*`, an ordinary global, already
  reachable). A switch calling a different function per case keeps a jump
  table at `-O2` too.
- Test: `llvm/test/CodeGen/RISCV/large-codemodel-jump-table.ll` (static and PIC
  large, each with and without `-function-sections`, medium PIC as control);
  fails without the change.

---

## x86-64 general-dynamic TLS (`mcmodel-large-tls-x86_64/`, `78e24eb023c1`)

x86-64 already had a working large PIC model. The one gap was general-dynamic
TLS, which emitted `leaq gd@TLSGD(%rip)` plus a 32-bit
`call __tls_get_addr@PLT` even under `-mcmodel=large`.
`X86AsmPrinter::LowerTlsAddr` (`X86MCInstLower.cpp`) now emits the psABI
large-model sequence, which GCC also emits:

```asm
  pushq   %rbx
.Ltmp0:
  leaq    .Ltmp0(%rip), %rbx
  movabsq $_GLOBAL_OFFSET_TABLE_-.Ltmp0, %r11
  addq    %r11, %rbx                    # %rbx = GOT base
  leaq    gd@TLSGD(%rip), %rdi
  movabsq $__tls_get_addr@PLTOFF, %rax
  addq    %rbx, %rax
  callq   *%rax
  popq    %rbx
```

- The relocations are `R_X86_64_GOTPC64`, `R_X86_64_TLSGD` and
  `R_X86_64_PLTOFF64`, all already supported by MC. Only codegen was missing.
- **The registers are fixed by the ABI.** Linkers byte-match the four
  instructions from the `leaq` onward when relaxing GD to IE or LE, so the
  PLTOFF value must be in RAX and the GOT base in RBX. An earlier version used
  call-clobbered scratch and failed to link with "TLS transition from
  R_X86_64_TLSGD to R_X86_64_GOTTPOFF ... failed". RBX is callee-saved, so it
  is saved around the sequence with CFI, as GCC does.
- Initial-exec keeps the 32-bit `gottpoff` form, as GCC does, because that is
  an ABI-level property. LLVM's local-exec is already more conservative than
  GCC's.
- Test: `llvm/test/CodeGen/X86/tls-large-code-model.ll`. No ABI question and
  no flag; a plain bug fix.

---

## Compatibility with GCC and GNU binutils

### AArch64

GCC 16 (series patches 01–04) emits the same GOT base, GOT offset and
initial-exec sequences. GNU as, ld.bfd and ld.gold with the binutils series
(01–03) support the operators and relocations.

| Aspect | LLVM / lld | GCC / GNU binutils | Notes |
|---|---|---|---|
| GOT base | `ADR` + `MOVW_PREL_G3..G0_NC` (+4…+16), scratch x17, one node per function | Same relocations; pseudo PIC register set once per function on entry | Identical relocations |
| GOT offset chunk order | Low chunk first; `GOTOFF_G3` on the final MOVK | Top chunk first; `movz #:gotoff_g3:` | Both valid under the rule below |
| MOV[NZ] relocation on a MOVK | lld keeps MOVK | ld.bfd and ld.gold keep MOVK (binutils 01, 03) | Must stay aligned |
| MOVN placeholder under `:gottprel_g1:` | llvm-mc emits MOVN | gas emits MOVZ | All linkers rewrite by sign |
| `:gotoff_g3:` on MOVK in textual assembly | Emitted by `clang -S`/`llc` | Accepted by gas (binutils 02); other MOV[NZ] operators rejected on MOVK | Lets Clang's textual output assemble with gas |
| IE→LE relaxation of MOVW GOTTPREL | Disabled (lld) | Disabled (ld.bfd, ld.gold) | Required |
| `_GLOBAL_OFFSET_TABLE_` | Start of `.got` (lld) | Start of `.got` (ld.bfd); +0x8000 bias with offsets relative to it (gold) | Always derive the GOT base from the symbol, never from `.got` |
| GD/LD TLS, signed GOT | Error | `sorry` / not supported | Neither implements them |
| FDE initial locations (large model) | 8 bytes, `R_AARCH64_PREL64` (integrated assembler) | 4 bytes, `R_AARCH64_PREL32`: GCC emits `.cfi_*` and GNU as builds the FDEs (so does Clang `-S` output assembled by gas) | Mixed objects link and unwind; only 8-byte FDEs reach code more than 2 GiB from `.eh_frame`. Personality and LSDA pointers are 8 bytes in both. Recorded in the RFC as an open point for a specification |

For the same source, GNU as and llvm-mc emit identical relocations (checked on
lld's own tests).

Things that would break interoperability if changed on the LLVM side:
- The operator spellings.
- The MOVN placeholder opcode and the chunk order: older linkers mishandle
  MOV[NZ] relocations on MOVK.
- Moving `:gotoff_g3:` or other MOV[NZ] operators onto different
  instructions, which gas may reject.

GCC-side interaction: `llvm-mc` assembles GCC's `.s` output, including its
`.eh_frame`, which a correctly configured GCC emits as `"a"` under PIC
(checked with GCC 16.2.0 on AArch64 and RISCV). An earlier version of this
README said GCC emits `"aw"` and `llvm-mc` rejects it ("changed section flags
for .eh_frame"). That came from GCC test compilers whose configure-time
linker check (`HAVE_LD_RO_RW_SECTION_MIXING`) had failed; only then does
`EH_TABLES_CAN_BE_READ_ONLY` default to 0 and make `.eh_frame` always
`"aw"`. Before testing interop against a GCC build, check its
`gcc/config.log`: `gcc_cv_ld_ro_rw_mix` should be `read-write` and
`gcc_cv_as_cfi_directive` should be `yes`. A build that failed these probes
probably also stops emitting `.cfi_*` directives, so its unwind tables differ
from a normal GCC's. On RISCV that hid a GCC bug (8-byte FDE pointers
missing under GNU as) until the GCC 16.2.0 port.

### RISCV64

GCC 16 (patches 05–07) implements large PIC **on by default**. It breaks the
same constraint the same way, with displacements in code and addresses in
`.data.rel.ro`, but with a different shape:

| Aspect | LLVM | GCC 16 |
|---|---|---|
| Local symbol | Pool entry `local-.Ltmp` (`ADD64`/`SUB64`) | Pool entry `.dword sym-.` (`ADD64`/`SUB64`) |
| Preemptible symbol | Per-function table `.Lrvlp_tbl.<fn>`, one anchor, one load per symbol | Per-symbol `.data.rel.ro` slot reached through its own pool displacement |
| Relocations in `.data.rel.ro` | `R_RISCV_64` / `R_RISCV_RELATIVE` | Same |
| Enabled by | `-mcmodel=large -fPIC` (since `aa9320e2847e`; `llc -riscv-large-pic` before it) | `-mcmodel=large -fPIC` |
| TLS | GOT-relative, ±2 GiB | Same |
| EH pointers | 0x1c/0x9c, `ADD64`/`SUB64` (`4fe0518a293f`) | Same; GCC defaults to `-fno-dwarf2-cfi-asm` in the large model so its FDE pointers are 8-byte (gas uses sdata4 for `.cfi_*` FDEs) |
| Jump tables | In the function's section, reached with `auipc`/`addi` (`98677af3cb50`; before it in `.rodata`, out of reach with far data) | In the function's section, reached with `lla` (upstream `JUMP_TABLES_IN_TEXT_SECTION` for `CM_LARGE`) |

Neither design adds relocations or a cross-object contract, so objects mix
freely at link time. GNU binutils needed no change for the RISCV large PIC
code itself. The `.eh_frame` handling did need changes:
- **Binutils 05:** before it, ld.bfd adjusted 8-byte `ADD64`/`SUB64` FDE
  fields twice after merging a duplicate CIE, and C++ exceptions silently
  called `std::terminate`. lld was always correct.
- **Binutils 04:** with code or `.eh_frame` more than 2 GiB from
  `.eh_frame_hdr`, lld already wrote an 8-byte `eh_frame_ptr` (0x1c) and a
  `DW_EH_PE_datarel|sdata8` search table (0x3c), and ld.bfd now does both.
  The first version of patch 04 widened only the table and silently
  truncated `eh_frame_ptr` when `.eh_frame` itself was far away. That was
  fixed on 2026-09-17, after libgcc without patch 09 segfaulted on such a
  layout.
- **Unwinders:** LLVM libunwind reads 0x3c tables natively. libgcc needs GCC
  patch 09 to binary search them; without it, it falls back to a linear scan.

### x86-64

The GD sequence is byte-compatible with GCC's `-mcmodel=large` output and uses
the relocations GNU ld and lld already relax.

### Limits shared by all toolchains

- AArch64: no general-/local-dynamic TLS and no signed GOT under large PIC;
  the GOT is limited to 4 GiB for initial-exec. Code more than 2 GiB from
  `.eh_frame` needs FDEs from LLVM's integrated assembler; GCC's and GNU as's
  FDE initial locations are 4 bytes.
- PLT stubs, and lld's AArch64 PIE range-extension thunks, are ADRP-based, so
  in dynamically linked programs, calls through the PLT still need the PLT
  within 4 GiB of the caller.
- RISCV TLS is limited to ±2 GiB between code and GOT.

---

## Verification

### LLVM alone

- **AArch64:** freestanding programs covering globals, jump tables, constant
  pools, computed goto and both TLS models, built with
  `clang -mcmodel=large -fPIC`. They link with `ld.lld` and run under
  `qemu-aarch64` at `-O1` (SelectionDAG) and `-O0` (GlobalISel), with zero
  ADRP. The MOVN (negative displacement) path was verified numerically.
- **RISCV PIC:** shared objects keep all dynamic relocations in
  `.data.rel.ro` and leave `.text` read-only. They run under `qemu-riscv64`
  and give identical results with `--relax` and `--no-relax`. The same input
  built with the absolute pool fails to link.
- **RISCV driver (2026-09-20, `ed825fc0ba39` and `aa9320e2847e`):** with the
  model on by default, a freestanding program mixing a preemptible global, a
  local global and a call, built straight through
  `clang --target=riscv64 -mcmodel=large -fPIC`, links with `ld.lld` and
  returns the expected value under `qemu-riscv64`. As a shared object its two
  dynamic relocations both land inside `.data.rel.ro` and `.text` carries
  none. `CodeGen/RISCV` (2599) and `MC/RISCV` (604) pass, as do
  `Driver/riscv-mcmodel.c` and `Driver/mcmodel.c`.
- **RISCV EH:** `CodeGen/RISCV`, `MC/RISCV` and `MC/ELF` pass (3466 lit
  tests).
- **RISCV jump tables:** the new lit test fails without `98677af3cb50` and
  passes with it; `CodeGen/RISCV`, `MC/RISCV` and `MC/ELF` (3467 tests) run
  with and without the commit differ only in that test (three MachO tests
  fail in both runs for lack of `llvm-otool`). Freestanding programs with all
  data 3 GiB above `.text` and a switch that keeps a jump table, static and
  PIC large, `-O2`/`-O0`: 8/8 link and run with lld and GNU ld, 0/8 link
  without the commit.
- **x86-64 GD:** executables and shared libraries link with the system
  toolchain and run. Local-dynamic, small PIC, large static and TLSDESC are
  unaffected.

### With GCC and GNU binutils (qemu-user, glibc sysroots)

| Check | Result |
|---|---|
| AArch64 runtime ABI matrix: large-PIC DSO + PIE, {GCC, Clang} × {GCC, Clang}, `-O2`/`-O0`; interposition, weak undefined, jump tables, computed goto, FP constants, IE/LE TLS | 24/24 with lld, ld.bfd and ld.gold (GCC 16.0.1; repeated with GCC 16.2.0) |
| Same matrix, Clang objects from `clang -fno-addrsig -S` assembled by gas | 24/24 with lld, ld.bfd and ld.gold (GCC 16.0.1; repeated with GCC 16.2.0, also in the 5 GiB layout, 24/24). gas turns Clang's large-model FDEs into `PREL32` (it builds them from `.cfi_*` with sdata4), where the integrated assembler emits `PREL64` |
| AArch64 far layout: freestanding static programs, data and GOT 5 GiB from the code | Runs with all three linkers; the small model fails to link (GCC 16.0.1; repeated with GCC 16.2.0: {GCC, Clang} × {GCC, Clang} objects at `-O2`/`-O0`, 24/24) |
| RISCV runtime ABI matrix with {GCC, Clang} objects (Clang via `-riscv-large-pic`, now `-mcmodel=large -fPIC`) | 16/16 with ld.bfd and lld (GCC 16.0.1 and 16.2.0) |
| RISCV far data layout: freestanding static programs, all data 3 GiB above `.text` | GCC 16.0.1 and 16.2.0: links and runs with ld.bfd and lld, medany fails to link. With GCC 16.2.0 and `98677af3cb50`: {GCC, Clang} × {GCC, Clang} objects at `-O2`/`-O0`, 16/16 (before that commit, the 4 links with a Clang `-O0` object failed on an out-of-range jump table) |
| RISCV far data layout, jump-table switch (static and PIC large, `-O2`/`-O0`) | With `98677af3cb50`: Clang objects 8/8 with ld.bfd and lld; without it 0/8 link. GCC 16.2.0 objects 8/8 |
| All of the above with Clang and GCC objects built at `-O1` and `-O3` (GCC 16.2.0, 2026-09-18) | AArch64 runtime matrix 24/24 with lld, ld.bfd and ld.gold, also with Clang textual output through gas; RISCV 16/16 with lld and ld.bfd. AArch64 5 GiB layout 24/24 with the integrated assembler and with gas; RISCV 3 GiB layout 16/16 with `98677af3cb50`. Jump-table switch: Clang 8/8 with `98677af3cb50` and 0/8 without, GCC 8/8, at both levels. C++ exceptions through the runtime matrices, GCC objects only: AArch64 6/6, RISCV 4/4 (the mixed Clang/GCC RISCV exception tests in the next row were not repeated at these levels; see `mcmodel-large-eh-riscv/README`). GCC's libgcc `.eh_frame_hdr` test (64-bit table, 8-byte `eh_frame_ptr`) unchanged with lld and ld.bfd on both targets. Small/medany controls fail to link |
| RISCV C++ exceptions across DSO and PIE with Clang, GCC and mixed objects, normal and with code 3 GiB from `.eh_frame` | 24/24 with lld and ld.bfd (GCC 16.0.1) |

**RISCV jump-table gap (found and fixed 2026-09-17):** jump tables were
emitted in `.rodata` but reached with a ±2 GiB `auipc`, in both the PIC and
the position-dependent large model; fixed by `98677af3cb50`
(`mcmodel-large-jt-riscv/`, see its section above). Block addresses take the
same lowering path but their labels are inside the function, so they were
never affected.

When testing interposition with Clang at `-O2`, pass
`-fsemantic-interposition`. Clang otherwise assumes
`-fno-semantic-interposition` for functions and calls a library's own
definition directly, which is standard Clang behavior, not a large-model
issue. `-fno-addrsig` is needed only because gas has no `.addrsig` directive.

---

## Building

The checkout's `build/` directory was reconfigured in place on 2026-09-20 with
`LLVM_TARGETS_TO_BUILD="AArch64;RISCV;X86"` and
`LLVM_ENABLE_PROJECTS="lld;clang"`, and builds normally there; `clang`, `lld`,
`llc`, `llvm-mc`, `opt`, `llvm-objdump`, `llvm-readobj`, `llvm-dwarfdump` and
`llvm-otool` were rebuilt there on that date, so `ninja` reports no work to do
and the binaries match the branch through `aa9320e2847e`. (An earlier note here
said CMake could no longer regenerate the directory at this path; that is no
longer the case.) The branch does not carry the RISCV EH or jump-table
commits, so neither do those binaries.

A second directory, `../build-mcmodel-large`, covers the rest of the branch
(2026-09-17: Release+assertions, `LLVM_ENABLE_PROJECTS=lld`,
`LLVM_TARGETS_TO_BUILD="AArch64;RISCV;X86"`), with `llc`, `lld`, `llvm-mc`
and the lit tools built but not `clang`. The MachO RISCV MC tests also need
`llvm-otool` built.

If you build as `RelWithDebInfo` with GCC, please use `-g0` instead of plain `-g`.
Plain `-g` creates `.debug_info` relocations that cross over the 2GB limit, and
some unittests and libraries fail to link with `ld.bfd`. Using `-g0` allows
everything to link successfully with GCC and Binutils `ld.bfd`.

My build scripts are in the [build-scripts](build-scripts) directory.

