//===--- RISCVConstantPoolValue.h - RISC-V constantpool value ---*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements the RISC-V specific constantpool value class.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RISCV_RISCVCONSTANTPOOLVALUE_H
#define LLVM_LIB_TARGET_RISCV_RISCVCONSTANTPOOLVALUE_H

#include "llvm/ADT/StringRef.h"
#include "llvm/CodeGen/MachineConstantPool.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/ErrorHandling.h"

namespace llvm {

class BlockAddress;
class GlobalValue;
class LLVMContext;

/// A RISCV-specific constant pool value.
class RISCVConstantPoolValue : public MachineConstantPoolValue {
  const GlobalValue *GV;
  const StringRef S;

public:
  /// What a pool entry holds. The two PC-relative forms are used by the
  /// prototype large PIC model: they store a displacement from the entry's own
  /// address, which is a link-time constant, so the entry needs no dynamic
  /// relocation and the pool may stay in a read-only section.
  enum class Form {
    /// The target's absolute address.
    Absolute,
    /// The displacement to the target itself. Only valid for a symbol whose
    /// distance is known at link time, i.e. a non-preemptible one.
    PCRel,
    /// The displacement to a writable slot holding the target's address. Used
    /// for preemptible symbols, whose distance is not a link-time constant;
    /// the slot takes the dynamic relocation instead.
    PCRelIndirect,
    /// The displacement to the start of the function's slot table. One entry
    /// per function bootstraps the table base; each slot is then reached as a
    /// fixed offset from it, so the bootstrap is paid once rather than per
    /// symbol. The symbol name holds the table's label.
    PCRelTable,
  };

private:
  Form EntryForm = Form::Absolute;

  RISCVConstantPoolValue(Type *Ty, const GlobalValue *GV, Form EntryForm);
  RISCVConstantPoolValue(LLVMContext &C, StringRef S, Form EntryForm);

private:
  enum class RISCVCPKind { ExtSymbol, GlobalValue };
  RISCVCPKind Kind;

public:
  ~RISCVConstantPoolValue() override = default;

  static RISCVConstantPoolValue *Create(const GlobalValue *GV);
  static RISCVConstantPoolValue *CreatePCRelative(const GlobalValue *GV);
  static RISCVConstantPoolValue *
  CreatePCRelativeIndirect(const GlobalValue *GV);
  static RISCVConstantPoolValue *CreatePCRelativeIndirect(LLVMContext &C,
                                                          StringRef S);
  static RISCVConstantPoolValue *CreatePCRelativeTable(LLVMContext &C,
                                                       StringRef TableSym);
  static RISCVConstantPoolValue *Create(LLVMContext &C, StringRef S);

  bool isGlobalValue() const { return Kind == RISCVCPKind::GlobalValue; }
  bool isExtSymbol() const { return Kind == RISCVCPKind::ExtSymbol; }
  Form getForm() const { return EntryForm; }
  bool isPCRelative() const { return EntryForm != Form::Absolute; }
  bool isIndirect() const { return EntryForm == Form::PCRelIndirect; }
  bool isTable() const { return EntryForm == Form::PCRelTable; }

  const GlobalValue *getGlobalValue() const { return GV; }
  StringRef getSymbol() const { return S; }

  int getExistingMachineCPValue(MachineConstantPool *CP,
                                Align Alignment) override;

  void addSelectionDAGCSEId(FoldingSetNodeID &ID) override;

  void print(raw_ostream &O) const override;

  bool equals(const RISCVConstantPoolValue *A) const;
};

} // end namespace llvm

#endif
