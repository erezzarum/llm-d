#!/bin/bash
set -Eeux

# purpose: builds and installs Libfabric from source
#
# Required environment variables:
# - ENABLE_EFA: Enable EFA installation (true/false, default: false)
# - CUDA_HOME: Cuda runtime path to install Libfabric against
# - LIBFABRIC_REPO: git remote to build Libfabric from
# - LIBFABRIC_VERSION: git ref to build UCX from
# - LIBFABRIC_PREFIX: prefix dir that contains installation path
# - USE_SCCACHE: whether to use sccache (true/false)
# - TARGETOS: OS type (ubuntu or rhel)

# Skip Libfabric installation if EFA support is not enabled, or on Ubuntu
if [ "${ENABLE_EFA}" != "true" ] || [ "$TARGETOS" != "rhel" ]; then
    echo "Libfabric installation skipped (ENABLE_EFA=${ENABLE_EFA}, TARGETOS=${TARGETOS})"
    exit 0
fi

cd /tmp

. /usr/local/bin/setup-sccache

git clone "${LIBFABRIC_REPO}" libfabric && cd libfabric
git checkout -q "${LIBFABRIC_VERSION}"

if [ "${USE_SCCACHE}" = "true" ]; then
    export CC="sccache gcc" CXX="sccache g++"
fi


./autogen.sh
./configure --prefix="${LIBFABRIC_PREFIX}" \
            --disable-verbs \
            --disable-psm3 \
            --disable-opx \
            --disable-usnic \
            --disable-rstream \
            --enable-efa \
            --with-cuda="${CUDA_HOME}" \
            --enable-cuda-dlopen \
            --with-gdrcopy="/usr/local" \
            --enable-gdrcopy-dlopen

make -j$(nproc)
make install


cd /tmp && rm -rf /tmp/libfabric

if [ "${USE_SCCACHE}" = "true" ]; then
    echo "=== Libfabric build complete - sccache stats ==="
    sccache --show-stats
fi
