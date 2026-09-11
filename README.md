# LLVM 23.1.1 Fork

This is my research fork of LLVM 23.1.1. It contains several significant changes:

- `ca3c039f3ae6da7b6014096da42a27e62df189a1`: support for `-mcmodel=large` PIC on AArch64.
- `608b46bda174cb88e8e432313a0eb0ac02c689b0`: support for `-mcmodel=large` PIC on RISCV64.
- `e85a34fc551e655843793774e136bf6f65859bff`: support for large TLS PIC on x86_64.
- `1005826ab2771b84a2db45c19adfb270b5ee1cb7`: support for building IREE 3.11.0.

## Notes:

- Code compiled with `-mcmodel=large -fPIC` on AArch64 will be ABI incompatible
with code compiled by GCC + Binutils, or with code compiled with LLVM Upstream.

- Code compiled with `-mcmodel=large -fPIC` on RISCV64 will be ABI incompatible
with code compiled by GCC + Binutils, or with code compiled with LLVM Upstream.

- Code compiled with `-mcmode=large -fPIC` on x86_64 is *probably* ABI compatible
with code compiled by GCC + Binutils, or with code compiled with LLVM Upstream.

- The option `-mcmodel=large -fPIC` is *not* supported on RISCV32.

Relevant documentation files:

- [README.AArch64](README.AArch64.md)
- [RFC-AArch64-MCModel-Large-PIC](RFC-AArch64-MCModel-Large-PIC.md)
- [README.RISCV](README.RISCV.md)
- [RISCV-DESIGN](RISCV-DESIGN.md)
- [RISCV-POST-388](RISCV-POST-388.md)
- [README.x86_64](README.x86_64.md)

The rest below is the canonical README from LLVM Upstream.

# The LLVM Compiler Infrastructure

[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/llvm/llvm-project/badge)](https://securityscorecards.dev/viewer/?uri=github.com/llvm/llvm-project)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/8273/badge)](https://www.bestpractices.dev/projects/8273)
[![libc++](https://github.com/llvm/llvm-project/actions/workflows/libcxx-build-and-test.yaml/badge.svg?branch=main&event=schedule)](https://github.com/llvm/llvm-project/actions/workflows/libcxx-build-and-test.yaml?query=event%3Aschedule)

Welcome to the LLVM project!

This repository contains the source code for LLVM, a toolkit for the
construction of highly optimized compilers, optimizers, and run-time
environments.

The LLVM project has multiple components. The core of the project is
itself called "LLVM". This contains all of the tools, libraries, and header
files needed to process intermediate representations and convert them into
object files. Tools include an assembler, disassembler, bitcode analyzer, and
bitcode optimizer.

C-like languages use the [Clang](https://clang.llvm.org/) frontend. This
component compiles C, C++, Objective-C, and Objective-C++ code into LLVM bitcode
-- and from there into object files, using LLVM.

Other components include:
the [libc++ C++ standard library](https://libcxx.llvm.org),
the [LLD linker](https://lld.llvm.org), and more.

## Getting the Source Code and Building LLVM

Consult the
[Getting Started with LLVM](https://llvm.org/docs/GettingStarted.html#getting-the-source-code-and-building-llvm)
page for information on building and running LLVM.

For information on how to contribute to the LLVM project, please take a look at
the [Contributing to LLVM](https://llvm.org/docs/Contributing.html) guide.

## Getting in touch

Join the [LLVM Discourse forums](https://discourse.llvm.org/), [Discord
chat](https://discord.gg/xS7Z362),
[LLVM Office Hours](https://llvm.org/docs/GettingInvolved.html#office-hours) or
[Regular sync-ups](https://llvm.org/docs/GettingInvolved.html#online-sync-ups).

The LLVM project has adopted a [code of conduct](https://llvm.org/docs/CodeOfConduct.html) for
participants to all modes of communication within the project.
