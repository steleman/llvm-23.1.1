# [RFC] AArch64: a large position-independent code model

## Summary

`-mcmodel=large` combined with PIC is rejected by Clang on AArch64 today, and
GCC does not implement it either. I would like to implement it, but doing so
requires choosing code sequences that AAELF64 does not specify. This RFC
proposes those sequences and asks whether the project wants them, and whether
ARM is willing to specify them.

A four-patch implementation is attached to this thread. Patches 1 and 2 are
useful on their own; patches 3 and 4 are the part that needs this discussion.

## Motivation

The large code model exists for images whose text and data cannot be assumed to
sit within ADRP's ±4GB reach. On AArch64 it is currently usable only when
building position-dependent code, which excludes it from every context where
PIE or shared libraries are required — which today is most of them. Distributions
build PIE by default, and hardened toolchains mandate it.

Concretely, this affects very large statically linked binaries, large AOT- or
JIT-generated images, and any build where the combined text plus data crosses
4GB and the result must still be position-independent. The current answer to
those users is "you cannot do that on AArch64".

## Current state

- Clang rejects `-mcmodel=large` unless the relocation model is static or the
  object format is MachO.
- GCC has no implementation.
- If the driver check is bypassed (for example by invoking `llc` directly),
  the backend silently emits **small code model sequences** — ADRP+ADD and
  ADRP+LDR. That is arguably worse than the error, since it produces an object
  that links fine until the image grows past 4GB. Patch 3 fixes this
  independently of whether the new sequences are accepted.

## What AAELF64 defines, and what it does not

AAELF64 allocates the building blocks:

| Code | Relocation | Operation |
|---|---|---|
| 0x12c–0x132 | `R_AARCH64_MOVW_GOTOFF_G0` … `_G3` | `G(GDAT(S)) - GOT` |
| 0x21b, 0x21c | `R_AARCH64_TLSIE_MOVW_GOTTPREL_G1`, `_G0_NC` | GOT offset for IE TLS |
| 0x235, 0x236 | `R_AARCH64_TLSDESC_OFF_G1`, `_G0_NC` | GOT offset for TLSDESC |
| 0x245–0x24b | `R_AARCH64_AUTH_MOVW_GOTOFF_G0` … `_G3` | signed-GOT variants |

What it does **not** define is a large PIC code model: there is no specified
sequence, and in particular no specified way to obtain the GOT base with more
than ±4GB of range. `MOVW_GOTOFF_G*` yields the offset of a symbol's GOT entry
from the GOT base, which is only useful once you have the GOT base in a
register.

That gap is the crux of this RFC. Everything below is a proposal.

## Proposed sequences

### The GOT base

Take the PC with `ADR`, then add a 64-bit PC-relative displacement built from
four `MOVW_PREL` chunks:

```
.Lpc:
  adr  xD, .Lpc
  movz x17, #:prel_g3:_GLOBAL_OFFSET_TABLE_+4
  movk x17, #:prel_g2_nc:_GLOBAL_OFFSET_TABLE_+8
  movk x17, #:prel_g1_nc:_GLOBAL_OFFSET_TABLE_+12
  movk x17, #:prel_g0_nc:_GLOBAL_OFFSET_TABLE_+16
  add  xD, xD, x17          // xD = GOT base, unlimited range
```

This is structurally what x86-64 already does for its large PIC model. For
`extern int a; int f(void) { return a; }` at `-mcmodel=large -fPIC`, Clang
emits:

```
.L0$pb:
  leaq    .L0$pb(%rip), %rax                     # PC
  movabsq $_GLOBAL_OFFSET_TABLE_-.L0$pb, %rcx    # 64-bit displacement
  addq    %rax, %rcx                             # GOT base
  movabsq $a@GOT, %rax                           # 64-bit GOT offset
  movq    (%rcx,%rax), %rax                      # load the GOT entry
  movl    (%rax), %eax
```

Same shape: PC plus a 64-bit displacement gives the GOT base, then a 64-bit
GOT offset indexes it. AArch64 needs four MOVZ/MOVK chunks where x86-64 has one
`movabsq`, and needs the per-chunk addends because its PC-relative relocations
are resolved against each instruction rather than a single anchor, but the model
is the same one. `:gotoff_gN:` is the analogue of `@GOT` in that sequence.

The addends are load-bearing and easy to get wrong. `R_AARCH64_MOVW_PREL_G*`
resolves as `S + A - P` against the address `P` of the instruction it
relocates. The four chunks live at different addresses, so each carries an
addend equal to its own distance from the `ADR`; every chunk is then a slice of
the same value, `_GLOBAL_OFFSET_TABLE_ - .Lpc`.

`x17` is the scratch. Using IP1 inside a leaf sequence is safe because the six
instructions are emitted as one indivisible unit with no call between them, so
they cannot race with a linker-inserted veneer. The destination register class
excludes x16/x17 accordingly.

### Symbol access

Preemptible symbols go through the GOT, indexed by a full 64-bit offset:

```
  movz x0, #:gotoff_g3:sym
  movk x0, #:gotoff_g2_nc:sym
  movk x0, #:gotoff_g1_nc:sym
  movk x0, #:gotoff_g0_nc:sym
  ldr  x0, [<got base>, x0]
```

Non-preemptible symbols skip the GOT and take the PC-relative sequence directly
against the symbol. Jump tables, constant pools and block addresses are all
module-local and take that same path. Jump table *dispatch* needs no change:
it indexes the table from a register, and its `ADR` targets a label inside the
same function. ELF calls also need no change, since `BL`/`CALL26` is range
extended by the linker.

### TLS

- **local-exec** works unmodified; its TPREL sequence hangs off the thread
  pointer and never uses ADRP. Its 24-bit reach bounds the TLS block, not the
  image, which is the same limit the small model has.
- **initial-exec** uses the MOVZ/MOVK form of GOTTPREL to build the GOT offset
  and indexes the GOT base with it. AAELF64 defines only two chunks here, so
  the GOT is bounded at 4GB; the image is not.
- **general-dynamic / local-dynamic** are *not* supported. They need TLSDESC,
  whose only defined sequence is ADRP-based. `R_AARCH64_TLSDESC_OFF_G1/_G0_NC`
  exist and would allow a MOVZ/MOVK form, but that needs a specified sequence
  too, and is left for a follow-up.

One linker-side subtlety: IE-to-LE relaxation must be **disabled** for the
MOVW GOTTPREL form. That optimization writes the thread-pointer value into the
field the GOT offset would have occupied, which is only valid when the load
consuming it is itself relocated and can be rewritten. This sequence indexes
the GOT base with a plain register-offset `LDR` carrying no relocation, so
relaxing drops the GOT entry and leaves that `LDR` dereferencing a
thread-pointer offset. This is a silent miscompile if missed; it is not visible
in assembly output and only appears once you link and run.

### Pointer authentication

Not supported. A signed GOT would need `R_AARCH64_AUTH_MOVW_GOTOFF_G*`, which
nothing implements. Both fallbacks are wrong — the plain `gotoff` sequence
silently drops the authentication, and `LOADgotAUTH` is ADRP-based and cannot
reach — so the combination is diagnosed in the driver and in both instruction
selectors.

## Assembler syntax

The `MOVW_GOTOFF` relocations have no assembler operator in AAELF64, and
binutils does not document one. This series introduces:

```
:gotoff_g0: :gotoff_g0_nc: :gotoff_g1: :gotoff_g1_nc:
:gotoff_g2: :gotoff_g2_nc: :gotoff_g3:
```

following the relocation names and the existing `:prel_gN:` / `:gottprel_gN:`
convention. If binutils would prefer different spellings, now is the time to
say so — matching from the start is much cheaper than diverging.

## Alternatives considered

**ADRP+ADD for the GOT base.** Two instructions instead of six, but it caps the
text-to-GOT distance at ±4GB. Data reached *through* the GOT stays unbounded,
so this covers a lot of real "my binary is huge" cases. Rejected as the primary
scheme because it is not actually a large code model: it reintroduces the exact
limit the model exists to escape, and fails at link time in precisely the cases
the user reached for `-mcmodel=large` to solve. It would be a reasonable
*additional* `medium`-style model if there is appetite for one.

**A literal pool holding a PREL64 displacement.** Three instructions
(`adr` + `ldr` literal + `add`), full range, no GOT base needed. But it only
works for non-preemptible symbols; preemptible ones still have to go through
the GOT, so it does not remove the need for a GOT base. Attractive as a future
fast path for the non-preemptible case.

**Absolute MOVZ/MOVK**, as the large static model uses, is not position
independent and would require text relocations.

## Costs

Instruction counts, `-O2`, `-fPIC`, one function per row:

| Source | small | large | notes |
|---|---|---|---|
| 1 preemptible global | 4 | 13 | includes the 6-instruction GOT base |
| 2 preemptible globals | 8 | 20 | GOT base shared |
| 4 preemptible globals | 16 | 34 | GOT base shared |
| 1 hidden global | 3 | 8 | |
| 2 hidden globals | 6 | 16 | not shared — see below |
| constant pool (one double) | 4 | 9 | |

The GOT base is modelled as its own node, so repeated GOT accesses in a
function share one computation: the marginal cost of an extra preemptible
global is 7 instructions against 4 in the small model.

Non-preemptible symbols are the weaker case: each access materializes its own
six-instruction PC-relative sequence, so two hidden globals cost 16 instructions
rather than sharing an anchor. Computing one per-function anchor and expressing
the rest as offsets from it is an obvious improvement and is left as follow-up
work rather than folded into an already large series.

## Implementation and testing

Four patches:

1. **MC** — the `:gotoff_gN:` specifiers, assembler syntax, and ELF relocation
   mapping. Implements relocations AAELF64 already specifies; useful on its own.
2. **lld** — `MOVW_GOTOFF_G*` and `TLSIE_MOVW_GOTTPREL_G1/_G0_NC`, including
   the relaxation fix above. Also independently useful.
3. **AArch64 codegen** — the code model, in both SelectionDAG and GlobalISel.
   FastISel needs nothing: it already declines when `!useSmallAddressing()` and
   falls back.
4. **Driver** — accept the combination on ELF; keep rejecting it on COFF, and
   reject it alongside `-fptrauth-elf-got`.

Testing is by execution rather than only by inspection. Freestanding programs
covering globals, jump tables, constant pools, computed goto and both supported
TLS models link with `ld.lld` and run correctly under `qemu-aarch64`, at `-O1`
(SelectionDAG) and `-O0` (GlobalISel), with no ADRP emitted anywhere. That
matters: inspecting `.s` output alone missed the IE-to-LE relaxation miscompile
described above, which only appeared at link-and-run time.

## Compatibility

Objects built with this are **not** interoperable with GCC or GNU as. GCC does
not implement the model, and the `:gotoff_gN:` operators do not exist in
binutils. Anything linking against such objects must be built with the same
compiler.

## Open questions

1. **Is ARM willing to specify a large PIC code model in AAELF64?** That is the
   question that decides whether this is an LLVM extension or a real ABI. I am
   happy to shape the sequences to whatever ARM prefers.
2. **Would binutils take the same `:gotoff_gN:` operator names?**
3. **Is the six-instruction GOT base the right trade**, or is there appetite for
   the cheaper ADRP+ADD variant as a separate medium-style model?
4. **Should `-mcmodel=large` without PIC also be revisited?** It has a related
   problem: its signed-GOT path is ADRP-based and equally unable to reach.
5. **General-dynamic TLS** via `TLSDESC_OFF_G*` — worth doing, and if so, is the
   sequence something ARM would specify?

Feedback on any of these, and on whether this is wanted at all, is very welcome.

