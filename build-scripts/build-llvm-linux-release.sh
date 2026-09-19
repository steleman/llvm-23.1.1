#!/bin/bash

llvm_version="23.1.1"
here="`pwd`"
topdir="`dirname ${here}`"
srcdir="${topdir}/llvm-${llvm_version}"
llvm_cmake_dir="${srcdir}/llvm"
ret=0
distro="`uname -s`"

if [ "${distro}" != "Linux" ] ; then
  echo "This cmake configure script only works on Linux."
  exit 1
fi

gsed="/usr/bin/sed"
python_executable="/usr/bin/python3"
build_type="RelWithDebInfo"
njobs="16"
outfile="${here}/llvm-build-release-j${njobs}.log"
systempath="/usr/bin:/usr/sbin:/usr/local/bin"

cuda_version="12.9"
rocm_version="6.4.3"

export CUDA="/usr/local/cuda-${cuda_version}"
export ROCM="/opt/rocm-${rocm_version}"
export PATH="/opt/bin:${CUDA}/bin:${ROCM}/bin:${systempath}"
export LD_LIBRARY_PATH="${here}/lib64:${here}/lib"
export GMAKE="/usr/bin/ninja"
export MAKE="${GMAKE}"
export CMAKE="/usr/bin/cmake"
export CC="/usr/bin/gcc"
export CXX="/usr/bin/g++"
export CFLAGS="-Wall -Wextra"
export CXXFLAGS="-Wall -Wextra"

${CC} --version
${CXX} --version

cat /dev/null > ${outfile}

echo "Building LLVM ..."
echo "ninja -v -j${njobs} >> ${outfile} 2>&1"
ninja -v -j${njobs} >> ${outfile} 2>&1
ret=$?

if [ ${ret} -ne 0 ] ; then
  echo "LLVM build FAILED."
  exit 1
fi

echo "LLVM build OK."

