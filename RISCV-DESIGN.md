# A position-independent large code model for RISC-V

Design proposal against riscv-non-isa/riscv-elf-psabi-doc#388.

## 1. What the psABI says today

The merged large code model text is explicit:

> The `large` code model allows the code to address the whole RV64 address
> space. Thus, this model is only available for RV64.
>
> By putting object addresses into literal pools, a 64-bit address literal can
> be loaded from the pool. Because calculating the pool entry address must use
> `auipc` and `addi` or `ld`, each pool entry has to be located within the
> range between -2GiB and +2GiB from its access instructions.
>
> **Large code model is disallowed to be used with PIC code model.**

So this is a request to *change* the psABI, not to fill a silence. #388's
discussion did leave the door open — noting that literal pools are effectively
hand-rolled GOTs, so a PIC variant is possible through dynamic relocations —
but nothing was specified. This document proposes the specifics.

## 2. The constraint that has to be broken

Three requirements that cannot all hold of a single section:

1. Pool entries must sit within ±2GiB of their access instructions, because
   they are reached with `auipc`. Today they are emitted into `.text`.
2. Under PIC, an entry holding a symbol address needs a dynamic relocation.
3. Dynamic relocations may not land in `.text`. A writable `.data.rel.ro` can
   hold them, but in a large image it may be more than 2GiB from the code.

LLVM's own comment in `RISCVELFTargetObjectFile::getSectionForConstant` states
the same thing from the other direction:

> The large code model has to put constant pools close to the program, so we
> put them in the `.text` section. Large code model doesn't support PIC, so
> there should be no dynamic relocations that would require `.data.rel.ro`
> (which could be too far away anyway).

## 3. Proposal: split the pool in two

Separate *what must be relocated at load time* from *what must be near the
code*, and connect them with a link-time constant.

**Level 1 — anchor, stays in `.text`.** One entry per function (or per module)
holding the displacement from itself to the indirection table. That is a label
difference between two sections, which RISC-V already expresses as an
`R_RISCV_ADD64` / `R_RISCV_SUB64` pair resolved by the static linker. It is a
link-time constant, so it needs **no dynamic relocation** and may sit in a
read-only, executable section.

**Level 2 — indirection table, in `.data.rel.ro`.** Holds real addresses and
takes the dynamic relocations, exactly as a GOT does. Being `.data.rel.ro` it
is writable while relocations are applied and read-only afterwards. It may sit
arbitrarily far from the code, because level 1 reaches it with a full 64-bit
displacement.

### Sequence

```asm
;; bootstrap, once per function
.Lpc:
  auipc a5, %pcrel_hi(.LCPanchor)
  addi  a5, a5, %pcrel_lo(.Lpc)     ; a5 = &.LCPanchor
  ld    a4, 0(a5)                   ; a4 = .Ltable - .LCPanchor
  add   a5, a5, a4                  ; a5 = &.Ltable

;; one load per symbol thereafter
  ld    a0, 0(a5)                   ; a0 = sym1
  ld    a1, 8(a5)                   ; a1 = sym2

        .p2align 3
.LCPanchor:                          ; in .text, link-time constant
        .quad .Ltable - .LCPanchor

        .section .data.rel.ro,"aw",@progbits
        .p2align 3
.Ltable:                             ; dynamically relocated
        .quad sym1
        .quad sym2
```

Offsets beyond the 12-bit `ld` immediate need one extra `lui`/`add`, the same
way any large structure is indexed.

## 4. What was validated

Hand-written assembly for both the naive and anchored forms was assembled with
`llvm-mc`, linked with `ld.lld`, and executed under `qemu-riscv64`.

| Check | Result |
|---|---|
| Anchored sequence computes correct addresses | runs, exit code 31 as expected |
| Naive per-symbol sequence | runs, exit code 42 as expected |
| Relocations in `.text` of the shared object | **none** |
| Relocations in `.data.rel.ro` | 4 × `R_RISCV_64`, 1 × `R_RISCV_RELATIVE` |
| `.text` section flags in the `.so` | `AX` — read-only, executable |
| Survives linker relaxation | identical result with `--relax` and `--no-relax` |
| New relocation types required | **none** |

The last row is the main practical advantage over the equivalent AArch64 work,
which needed seven new relocation specifiers and linker support for them.
Everything here uses relocations RISC-V already has and lld already implements.

A hidden symbol placed in the table draws `R_RISCV_RELATIVE` rather than a
symbolic `R_RISCV_64`, which is the cheap base-relative form — so local symbols
routed through the table cost startup work but not symbol lookup.

## 5. Cost

Measured, not estimated. Instructions in a function loading N preemptible
globals, `-O2`:

| N | medium PIC (today, ±2GiB) | large PIC, anchored |
|---|---|---|
| 1 | 4 | 7 |
| 2 | 8 | 10 |
| 4 | 16 | 16 |
| 8 | 32 | 28 |

The two are equal at N = 4 and the proposed model is *cheaper* beyond it, which
is a pleasant result for a model usually assumed to be strictly worse. The
bootstrap is loop-invariant and function-local, so it hoists.

Data cost is one 8-byte table slot per preemptible symbol -- which the GOT
would have needed anyway -- plus one 8-byte pool entry per function.

For non-preemptible symbols there is a genuine choice, and it should probably
be a tunable rather than a fixed rule:

| Approach | Instructions | Startup cost |
|---|---|---|
| Route through the table | 1 (amortized) | one `R_RISCV_RELATIVE` per symbol |
| Displacement in the `.text` pool | 4 | none |

Hot code wants the table; code that cares about startup relocation count and
page dirtying wants the displacement form.

## 6. Open questions for #388

1. **Is a PIC large model wanted in the psABI at all**, or is the position that
   anything needing >2GiB of PIC-addressable code should use a different
   mechanism entirely?
2. **Is the two-level split acceptable**, or would the committee prefer
   extending the real GOT with a 64-bit-range access sequence? The latter needs
   a new relocation — something like a `GOT_OFF64` — whereas this needs none.
   The trade is a second GOT-like table against a new relocation.
3. **Should the indirection table be per-module or per-function?** Per-module
   shares entries and shrinks data; per-function keeps displacements short and
   allows dead-stripping with the function.
4. **Does `.data.rel.ro` place the table correctly** for all the deployment
   targets the large model exists to serve, particularly embedded systems
   without virtual memory, which #388 cites as a motivation?
5. **Default for non-preemptible symbols** — table or displacement?

## 7. Implementation plan for LLVM

Assuming the design survives review, the work is smaller than the AArch64
equivalent, because no MC or lld changes are needed.

1. **Fix the existing latent bug first, independently.** `RISCVTargetLowering::getAddr`
   returns from an `isPositionIndependent()` branch *before* the code model
   switch is consulted, so under PIC the code model is ignored entirely —
   `-code-model=small`, `medium` and `large` produce byte-identical output.
   Whatever happens to this proposal, `-mcmodel=large -fPIC` silently emitting
   ±2GiB sequences is worth correcting.
2. **Constant pool placement** — ~~`RISCVELFTargetObjectFile::getSectionForConstant`
   grows a PIC case emitting the two sections instead of one.~~ **This does not
   work, found by trying it.** `AsmPrinter::emitConstantPool` does choose a
   section per entry, but for a `MachineConstantPoolValue` it passes
   `C == nullptr`, and `MachineConstantPoolEntry::getSectionKind` returns
   `ReadOnlyWithRel` for both flavors. So the section decision has no
   discriminator and cannot separate the read-only anchors from the writable
   slots. The writable table has to come from somewhere other than the machine
   constant pool: synthetic module globals, end-of-module emission from the
   AsmPrinter (as `EmitHwasanMemaccessSymbols` does), or an upstream change
   passing the `MachineConstantPoolValue` to `getSectionForConstant`.

   **Resolved by end-of-module emission.** The AsmPrinter records each target
   needing a slot as it emits the pool entry that references it — it is the
   same component doing both — and writes the table into `.data.rel.ro` from
   `emitEndOfAsmFile`. Slots are keyed on the target `MCSymbol`, so globals and
   external symbols (libcall targets) share one path. No module mutation, no
   upstream API change.
3. **Address lowering** — extend `getLargeGlobalAddress` with the PC-relative
   form, and teach `getAddr` to reach it under PIC. **Prototyped**, behind
   `-riscv-large-pic` (off by default, so the committed diagnostic stays the
   default behaviour). Covers non-preemptible symbols, for both data addressing
   and call targets — the call path in `LowerCall` materializes addresses the
   same way and needed converting too, which the original plan missed.

   Now covers preemptible symbols too, via the slot table, for data addressing
   and for calls including libcall targets.

   Validated: a module mixing preemptible data, local data and a call links as
   a shared object with its dynamic relocations confined to `.data.rel.ro`,
   leaves `.text` read-only with none, and runs correctly under
   `qemu-riscv64`. The same input built with today's absolute pool fails to
   link at all, with `relocation R_RISCV_64 cannot be used against symbol`.
4. **Anchor management** — **done**, one table per function. Slot indices are
   allocated during lowering and held in `RISCVMachineFunctionInfo`; the
   AsmPrinter emits the table from `emitFunctionBodyEnd`. Per-module sharing
   is still a follow-up: it would need cross-function coordination but would
   let unrelated functions share slots.

   Note that slots are allocated in the order lowering first sees each symbol,
   which is DAG order rather than source order. Deterministic, but tests must
   not assume source order.
5. **Driver** — relax the `large` + PIC rejection in `addMCModel`, keeping the
   RV32 restriction, which matches the psABI's "only available for RV64".

GlobalISel needs auditing the same way AArch64's did, but it is lower priority
here: unlike AArch64, GlobalISel is **not** the RISC-V default at `-O0` — the
default `-O0` pipeline runs no GlobalISel passes — though it does work when
requested with `-global-isel`. So an opt-in user could still get the wrong
sequences, and it should be handled before the driver flag is relaxed.
