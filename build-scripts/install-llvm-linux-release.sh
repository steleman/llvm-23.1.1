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

llvmdir="/opt/llvm/${llvm_version}"
llvmbindir="${here}/bin"
gsed="/usr/bin/sed"
python_executable="/usr/bin/python3"
build_type="RelWithDebInfo"
outfile="${here}/llvm-install-release.log"
destdir="${topdir}/install-llvm-mcmodel-large"
llvm_install_bindir="${destdir}/opt/llvm/${llvm_version}/bin"

cuda_version="12.9"
rocm_version="6.4.3"

export CUDA="/usr/local/cuda-${cuda_version}"
export ROCM="/opt/rocm-${rocm_version}"
export PATH="/opt/bin:${CUDA}/bin:${ROCM}/bin:${here}/bin:${llvmbindir}:${PATH}"
export LD_LIBRARY_PATH="${here}/lib64:${here}/lib"
export GMAKE="/usr/bin/ninja"
export MAKE="${GMAKE}"
export CMAKE="/usr/bin/cmake"
export CC="/usr/bin/gcc"
export CXX="/usr/bin/g++"
export CFLAGS="-Wall -Wextra"
export CXXFLAGS="-Wall -Wextra"

if [ ! -d ${destdir} ] ; then
  mkdir -p ${destdir}
fi

export DESTDIR="${destdir}"

echo "Fixing OCaml docs crap ..."
mkdir -p ${here}/docs/ocamldoc/html

cat /dev/null > ${outfile}

echo "Installing LLVM ..."
echo "cmake --install ${here} --prefix ${DESTDIR} >> ${outfile} 2>&1"
cmake --install ${here} --prefix ${DESTDIR} >> ${outfile} 2>&1
ret=$?

if [ ${ret} -ne 0 ] ; then
  echo "cmake --install ${here} --prefix ${DESTDIR} FAILED."
  exit 1
fi

if [ -f ${here}/bin/llvm-lit ] ; then
  echo "cp -fp ${here}/bin/llvm-lit ${llvm_install_bindir}/"
  cp -fp ${here}/bin/llvm-lit ${llvm_install_bindir}/
  echo "chmod 0755 ${llvm_install_bindir}/llvm-lit"
  chmod 0755 ${llvm_install_bindir}/llvm-lit
fi

echo "Dealing with the bullshit LLVM installation directories ..."

bullshit_destdir="${destdir}/${destdir}"
bullshit_tarball="bullshit-llvm-tarball.tar"
real_llvmdir="${destdir}/${llvmdir}"

if [ ! -e ${bullshit_destdir} ] ; then
  echo "BULLSHIT ${bullshit_destdir} doesn't exist."
  exit 1
fi

if [ ! -e ${real_llvmdir} ] ; then
  echo "REAL ${real_llvmdir} doestn't exist."
  exit 1
fi

echo "cd ${bullshit_destdir}"
cd ${bullshit_destdir}

tarball_dirlist="bin examples include lib local python_packages share src"

for file in \
  bin \
  examples \
  include \
  lib \
  local \
  python_packages \
  share \
  src
do
  if [ ! -e ${bullshit_destdir}/${file} ] ; then
    echo "Directory ${bullshit_destdir}/${file} doesn't exist when it should."
    exit 1
  fi
done

echo "tar cf ${real_llvmdir}/${bullshit_tarball} ${tarball_dirlist}"
tar cf ${real_llvmdir}/${bullshit_tarball} ${tarball_dirlist}

echo "cd ${real_llvmdir}"
cd ${real_llvmdir}

echo "tar xf ${bullshit_tarball} --touch"
tar xf ${bullshit_tarball} --touch

echo "cd ${destdir}"
cd ${destdir}

if [ -d ${destdir}/src ] ; then
  echo "rm -rf ${destdir}/src"
  rm -rf ${destdir}/src
fi

echo "cd ${here}"
cd ${here}

echo "Install Done."

