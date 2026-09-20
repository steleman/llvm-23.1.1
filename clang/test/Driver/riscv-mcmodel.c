// RUN: %clang --target=riscv32 -### -c -mcmodel=small %s 2>&1 | FileCheck --check-prefix=SMALL %s
// RUN: %clang --target=riscv64 -### -c -mcmodel=small %s 2>&1 | FileCheck --check-prefix=SMALL %s

// RUN: %clang --target=riscv32 -### -c -mcmodel=medlow %s 2>&1 | FileCheck --check-prefix=SMALL %s
// RUN: %clang --target=riscv64 -### -c -mcmodel=medlow %s 2>&1 | FileCheck --check-prefix=SMALL %s

// RUN: %clang --target=riscv32 -### -c -mcmodel=medium %s 2>&1 | FileCheck --check-prefix=MEDIUM %s
// RUN: %clang --target=riscv64 -### -c -mcmodel=medium %s 2>&1 | FileCheck --check-prefix=MEDIUM %s

// RUN: %clang --target=riscv32 -### -c -mcmodel=medany %s 2>&1 | FileCheck --check-prefix=MEDIUM %s
// RUN: %clang --target=riscv64 -### -c -mcmodel=medany %s 2>&1 | FileCheck --check-prefix=MEDIUM %s

// RUN: not %clang --target=riscv32 -### -c -mcmodel=large %s 2>&1 | FileCheck --check-prefix=ERR-LARGE %s
// RUN: %clang --target=riscv64 -### -c -mcmodel=large %s 2>&1 | FileCheck --check-prefix=LARGE %s

// The large code model is usable as position-independent code.
// RUN: %clang --target=riscv64 -### -c -mcmodel=large -fpic %s 2>&1 | FileCheck --check-prefix=LARGE %s
// RUN: %clang --target=riscv64 -### -c -mcmodel=large -fPIC %s 2>&1 | FileCheck --check-prefix=LARGE %s
// RUN: %clang --target=riscv64 -### -c -mcmodel=large -fpie %s 2>&1 | FileCheck --check-prefix=LARGE %s
// It remains RV64-only, PIC or not.
// RUN: not %clang --target=riscv32 -### -c -mcmodel=large -fpic %s 2>&1 | FileCheck --check-prefix=ERR-LARGE %s

// SMALL: "-mcmodel=small"
// MEDIUM: "-mcmodel=medium"
// LARGE: "-mcmodel=large"

// ERR-LARGE:  error: unsupported argument 'large' to option '-mcmodel=' for target 'riscv32'
