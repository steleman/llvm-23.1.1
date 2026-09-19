#!/bin/bash

llvm_version="23.1.1"
here="`pwd`"
topdir="`dirname ${here}`"
srcdir="${topdir}/llvm-${llvm_version}"
lldb_incdir="${srcdir}/lldb/include/lldb"
build_lldbincdir="${here}/include/lldb"
llvm_cmake_dir="${srcdir}/llvm"
outfile="${here}/configure-llvm-release.out"
cmake_outfile="${here}/cmake-configure-llvm-release.out"
ret=0
distro="`uname -s`"
linker_type="BFD"
bfd_linker_flags=""

if [ "${distro}" != "Linux" ] ; then
  echo "This cmake configure script only works on Linux."
  exit 1
fi

cuda_version="12.9"
rocm_version="6.4.3"

export CUDA="/usr/local/cuda-${cuda_version}"
export ROCM="/opt/rocm-${rocm_version}"

export PATH="/opt/bin:/usr/local/${CUDA}/bin:/opt/${ROCM}/bin:/opt/bin:${PATH}"
export GMAKE="/usr/bin/ninja"
export MAKE="${GMAKE}"
export CMAKE="/usr/bin/cmake"

export CC="/usr/bin/gcc"
export CXX="/usr/bin/g++"
export CFLAGS="-Wall -Wextra"
export CXXFLAGS="-Wall -Wextra"
export CPPFLAGS=""
export CMAKE_FLAGS=""

gsed="/usr/bin/sed"
cmakear="/usr/bin/ar"
python_executable="/usr/bin/python3"
python_version="3.13"
build_type="RelWithDebInfo"

libffi_incdir="/usr/include"
libffi_libdir="/usr/lib64"
llvm_spirv="/opt/bin/llvm-spirv"

prefix="/opt/llvm/${llvm_version}"
cmake_install_bindir="${prefix}/bin"
cmake_install_libdir="${prefix}/lib64"
cmake_install_rpath="${cmake_install_libdir}"
cmake_build_rpath="${here}/lib64;${here}/lib;${cmake_install_rpath}"
cmake_install_libexecdir="${prefix}/libexec"
cmake_install_incdir="${prefix}/include"
cmake_install_datadir="${prefix}/share"
llvm_targets="X86\;NVPTX\;AMDGPU\;RISCV\;AArch64\;SPIRV"

cmake_flags="-G Ninja"
cmake_flags="${cmake_flags} -DCMAKE_INSTALL_PREFIX=${prefix}"
cmake_flags="${cmake_flags} -DCMAKE_BUILD_TYPE=${build_type}"
cmake_flags="${cmake_flags} -DCMAKE_C_VISIBILITY_PRESET:STRING=default"
cmake_flags="${cmake_flags} -DCMAKE_CXX_VISIBILITY_PRESET:STRING=default"
cmake_flags="${cmake_flags} -DCMAKE_C_COMPILER=${CC}"
cmake_flags="${cmake_flags} -DCMAKE_CXX_COMPILER=${CXX}"
cmake_flags="${cmake_flags} -DCMAKE_C_FLAGS=${CFLAGS}"
cmake_flags="${cmake_flags} -DCMAKE_CXX_FLAGS=${CXXFLAGS}"
cmake_flags="${cmake_flags} -DCMAKE_C_FLAGS_RELEASE=${CFLAGS}"
cmake_flags="${cmake_flags} -DCMAKE_CXX_FLAGS_RELEASE=${CXXFLAGS}"
cmake_flags="${cmake_flags} -DCMAKE_LINKER_TYPE:STRING=${linker_type}"
cmake_flags="${cmake_flags} -DCMAKE_AR:FILEPATH=${cmakear}"
cmake_flags="${cmake_flags} -DCMAKE_C_STANDARD=11"
cmake_flags="${cmake_flags} -DCMAKE_CXX_STANDARD=17"
cmake_flags="${cmake_flags} -DCMAKE_C_EXTENSIONS:BOOL=ON"
cmake_flags="${cmake_flags} -DCMAKE_CXX_EXTENSIONS:BOOL=ON"
cmake_flags="${cmake_flags} -DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=ON"
cmake_flags="${cmake_flags} -DCMAKE_BUILD_TYPE:STRING=${build_type}"
cmake_flags="${cmake_flags} -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON"
cmake_flags="${cmake_flags} -DCMAKE_BUILD_RPATH:STRING=${cmake_build_rpath}"
cmake_flags="${cmake_flags} -DCMAKE_INSTALL_RPATH:STRING=${cmake_install_rpath}"

cmake_flags="${cmake_flags} -DCMAKE_INSTALL_BINDIR:FILEPATH=${cmake_install_bindir}"
cmake_flags="${cmake_flags} -DCMAKE_INSTALL_LIBDIR:FILEPATH=${cmake_install_libdir}"
cmake_flags="${cmake_flags} -DCMAKE_INSTALL_LIBEXECDIR:FILEPATH=${cmake_install_libexecdir}"
cmake_flags="${cmake_flags} -DCMAKE_INSTALL_INCLUDEDIR:FILEPATH=${cmake_install_incdir}"
cmake_flags="${cmake_flags} -DCMAKE_INSTALL_DATADIR:FILEPATH=${cmake_install_datadir}"
cmake_flags="${cmake_flags} -DCMAKE_INSTALL_DATAROOTDIR:FILEPATH=${cmake_install_datadir}"
cmake_flags="${cmake_flags} -DLLVM_TARGETS_TO_BUILD:STRING=${llvm_targets}"
cmake_flags="${cmake_flags} -DCMAKE_MAKE_PROGRAM:FILEPATH=${GMAKE}"
cmake_flags="${cmake_flags} -DCMAKE_ASM_COMPILER:FILEPATH=${CC}"
cmake_flags="${cmake_flags} -DCMAKE_SUPPRESS_REGENERATION:BOOL=ON"
cmake_flags="${cmake_flags} -DLLVM_BUILD_TOOLS:BOOL=ON"
cmake_flags="${cmake_flags} -DLLVM_INCLUDE_TOOLS:BOOL=ON"
cmake_flags="${cmake_flags} -DLLVM_BUILD_TESTS:BOOL=ON"
cmake_flags="${cmake_flags} -DLLVM_INCLUDE_TESTS:BOOL=ON"
cmake_flags="${cmake_flags} -DLLVM_ENABLE_THREADS:BOOL=ON"
cmake_flags="${cmake_flags} -DLLVM_BUILD_32_BITS:BOOL=OFF"
cmake_flags="${cmake_flags} -DLLVM_BUILD_EXAMPLES:BOOL=ON"
cmake_flags="${cmake_flags} -DLLVM_INCLUDE_EXAMPLES:BOOL=ON"
cmake_flags="${cmake_flags} -DLLVM_ENABLE_EH:BOOL=ON"
cmake_flags="${cmake_flags} -DLLVM_ENABLE_PIC:BOOL=ON"
cmake_flags="${cmake_flags} -DLLVM_ENABLE_RTTI:BOOL=ON"
cmake_flags="${cmake_flags} -DLLVM_ENABLE_WARNINGS:BOOL=ON"
cmake_flags="${cmake_flags} -DLLVM_ENABLE_PEDANTIC:BOOL=ON"
cmake_flags="${cmake_flags} -DLLVM_ENABLE_ZLIB:BOOL=ON"
cmake_flags="${cmake_flags} -DLLVM_ENABLE_FFI:BOOL=ON"
cmake_flags="${cmake_flags} -DLLVM_SPIRV=${llvm_spirv}"
cmake_flags="${cmake_flags} -DFFI_INCLUDE_DIR:FILEPATH=${libffi_incdir}"
cmake_flags="${cmake_flags} -DFFI_LIBRARY_DIR:FILEPATH=${libffi_libdir}"
cmake_flags="${cmake_flags} -DLLVM_BUILD_STATIC:BOOL=OFF"
cmake_flags="${cmake_flags} -DLLVM_BUILD_LLVM_DYLIB:BOOL=ON"
cmake_flags="${cmake_flags} -DLLVM_LINK_LLVM_DYLIB:BOOL=OFF"
cmake_flags="${cmake_flags} -DLLVM_COMPILER_IS_GCC_COMPATIBLE:BOOL=ON"
cmake_flags="${cmake_flags} -DLLVM_ENABLE_PROJECTS='llvm;clang;clang-tools-extra;mlir;lldb;lld;polly'"
cmake_flags="${cmake_flags} -DLLVM_ENABLE_RUNTIMES='openmp;compiler-rt;libcxxabi;libunwind;libcxx'"
cmake_flags="${cmake_flags} -DLLVM_ENABLE_Z3_SOLVER:BOOL=ON"
cmake_flags="${cmake_flags} -DLLVM_INSTALL_UTILS:BOOL=ON"
cmake_flags="${cmake_flags} -DMLIR_ENABLE_BINDINGS_PYTHON:BOOL=ON"
cmake_flags="${cmake_flags} -DLLDB_USE_SYSTEM_DEBUGSERVER:BOOL=ON"
cmake_flags="${cmake_flags} -DPython3_EXECUTABLE:FILEPATH=${python_executable}"
cmake_flags="${cmake_flags} -DLIBOMP_ARCH=X86"
cmake_flags="${cmake_flags} -DLIBOMP_LIB_TYPE=normal"
cmake_flags="${cmake_flags} -DLIBOMP_OMP_VERSION=50"
cmake_flags="${cmake_flags} -DOPENMP_ENABLE_LIBOMPTARGET=on"

${CC} --version
${CXX} --version

cat /dev/null > ${outfile}
echo "Running ${CMAKE} ${CMAKE_FLAGS} ${cmake_flags} ${llvm_cmake_dir}"
echo "Running ${CMAKE} ${CMAKE_FLAGS} ${cmake_flags} ${llvm_cmake_dir}" >> ${cmake_outfile} 2<&1
echo "Running ${CMAKE} ${CMAKE_FLAGS} ${cmake_flags} ${llvm_cmake_dir}" >> ${outfile} 2>&1
${CMAKE} ${CMAKE_FLAGS} ${cmake_flags} ${llvm_cmake_dir} >> ${outfile} 2>&1
ret=$?

if [ ${ret} -ne 0 ] ; then
  echo "CMake configuration FAILED."
  exit 1
fi

ninjafile="${here}/build.ninja"
jsonfile="${here}/compile_commands.json"

if [ ! -f ${ninjafile} ] ; then
  echo "This configuration is broken. ${ninjafile} is missing."
  exit 1
fi

if [ ! -f ${jsonfile} ] ; then
  echo "This configuration is broken. ${jsonfile} is missing."
  exit 1
fi

if [ ! -f "${ninjafile}.orig" ] ; then
  cp -fp ${ninjafile} "${ninjafile}.orig"
fi

if [ ! -f "${jsonfile}.orig" ] ; then
  cp -fp ${jsonfile} "${jsonfile}.orig"
fi

sed -i 's#-D_GNU_SOURCE#-D_GNU_SOURCE -D_XOPEN_SOURCE=700#g' ${ninjafile}
sed -i 's#-D__STDC_LIMIT_MACROS#-D__STDC_LIMIT_MACROS -DNDEBUG#g' ${ninjafile}
sed -i 's#-DNDEBUG#-DNDEBUG -DLLVM_ENABLE_DUMP#g' ${ninjafile}
sed -i 's#-fvisibility-inlines-hidden##g' ${ninjafile}
sed -i 's#-fvisibility=hidden##g' ${ninjafile}
sed -i 's#-g #-g0 -O2 #g' ${ninjafile}
sed -i 's#-O1 #-O2 #g' ${ninjafile}
sed -i 's#-O3 #-O2 #g' ${ninjafile}
sed -i 's#-fno-semantic-interposition#-mcmodel=large -fno-semantic-interposition#g' ${ninjafile}
sed -i 's#-fno-semantic-interposition#-mcmodel=large -fno-semantic-interposition#g' ${jsonfile}

echo "touch -r ${ninjafile}.orig -acm ${ninjafile}"
touch -r "${ninjafile}.orig" -acm ${ninjafile}
touch -r "${ninjafile}.orig" -acm ${ninjafile}

echo "touch -r ${jsonfile}.orig -acm ${jsonfile}"
touch -r "${jsonfile}.orig" -acm ${jsonfile}
touch -r "${jsonfile}.orig" -acm ${jsonfile}

echo "CMake configuration finished."
echo "CMake configuration finished." >> ${outfile} 2>&1

