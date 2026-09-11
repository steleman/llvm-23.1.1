Following up on the large+fpic question raised earlier in this thread.

I've implemented a position-independent large code model in LLVM to see
whether it's practical, and it is — with no new relocation types. Sharing the
design in case the committee wants to specify one.

## The constraint

Three requirements that can't all hold of one section:

1. Pool entries must be within ±2GiB of their access instructions, since they
   are reached with `auipc`.
2. Under PIC, an entry holding a symbol address needs a dynamic relocation.
3. Dynamic relocations can't live in `.text`, and a writable section may be
   further than 2GiB away.

## Proposal: hold a displacement, not an address

A pool entry stores the displacement from its own address to the target. That
is a label difference — an `R_RISCV_ADD64`/`R_RISCV_SUB64` pair resolved by
the static linker — so it needs no dynamic relocation and the pool can stay
read-only, beside the code:

```asm
.LCPI0_0:
.Ltmp0:
  .quad local-.Ltmp0
      auipc a0, %pcrel_hi(.LCPI0_0)
      addi  a0, a0, %pcrel_lo(.Lpcrel_hi0)   ; a0 = &entry
      ld    a1, 0(a0)                        ; a1 = local - &entry
      add   a0, a0, a1                       ; a0 = &local
```

A preemptible symbol's distance isn't a link-time constant, so it's reached
through a writable slot in `.data.rel.ro` holding its address, which takes the
dynamic relocation — the "literal pools are hand-rolled GOTs" observation from
earlier in the thread, made concrete. Those slots form one table per function,
bootstrapped once, so each additional symbol costs a single load:

```asm
      auipc a0, %pcrel_hi(.LCPI0_0)   ; bootstrap, once per function
      addi  a0, a0, %pcrel_lo(...)
      ld    a1, 0(a0)
      add   a0, a0, a1                ; a0 = table base
      ld    a1, 0(a0)                 ; one load per symbol
      ld    a2, 8(a0)
```

## Cost

Measured, `-O2`, instructions in a function loading N preemptible globals:

| N | medium PIC | large PIC (anchored) |
|---|---|---|
| 1 | 4 | 7 |
| 2 | 8 | 10 |
| 4 | 16 | 16 |
| 8 | 32 | 28 |

Break-even at four symbols and cheaper beyond, which surprised me for a large
code model. Data cost is one 8-byte slot per preemptible symbol — which the
GOT would have needed anyway — plus one 8-byte pool entry per function.

## What was verified

A module mixing preemptible data, local data and a call:

- links as a shared object with its dynamic relocations confined to
  `.data.rel.ro`, and `.text` left read-only with none;
- executes correctly under `qemu-riscv64`;
- gives identical results with `--relax` and `--no-relax`.

The same input built with today's absolute pool doesn't link at all:
`relocation R_RISCV_64 cannot be used against symbol`.

No new relocation types are required. Everything uses relocations RISC-V
already has and lld already implements.

## Questions

1. Is a PIC large model wanted in the psABI at all, or is the position that
   anything needing >2GiB of PIC-addressable code should use another mechanism?
2. Is the two-level split acceptable, or would you prefer extending the real
   GOT with a 64-bit-range access sequence? That needs a new relocation —
   something like a `GOT_OFF64` — where this needs none. The trade is a second
   GOT-like table against a new relocation type.
3. Per-function or per-module table? Per-module shares slots and shrinks data;
   per-function keeps offsets small and dead-strips with the function.
4. Does `.data.rel.ro` place the table correctly for the embedded,
   no-virtual-memory targets cited as a motivation for the large model?

Happy to reshape any of this to whatever the committee prefers — the
implementation is a means of checking the design is sound, not a fait accompli.
