#!/bin/bash
set -Eeux

# purpose: builds NIXL from source, gated by `BUILD_NIXL_FROM_SOURCE`
#
# Optional environment variables:
# - ENABLE_EFA: Enable EFA support in NIXL (true/false, default: false)
: "${ENABLE_EFA:=false}"
# Required environment variables:
# - BUILD_NIXL_FROM_SOURCE: if nixl should be installed by vLLM or has been built from source in the builder stages
# - NIXL_REPO: Git repo to use for NIXL
# - NIXL_VERSION: Git ref to use for NIXL
# - NIXL_PREFIX: Path to install NIXL to
# - UCX_PREFIX: Path to UCX installation
# - LIBFABRIC_PREFIX: Path to Libfabric installation
# - VIRTUAL_ENV: Path to the virtual environment
# - USE_SCCACHE: whether to use sccache (true/false)
# - TARGETOS: OS type (ubuntu or rhel)

if [ "${BUILD_NIXL_FROM_SOURCE}" = "false" ]; then
    echo "NIXL will be installed be vLLM and not built from source."
    exit 0
fi

cd /tmp

. /usr/local/bin/setup-sccache
. "${VIRTUAL_ENV}/bin/activate"

git clone "${NIXL_REPO}" nixl && cd nixl
git checkout -q "${NIXL_VERSION}"

if [ "${USE_SCCACHE}" = "true" ]; then
    export CC="sccache gcc" CXX="sccache g++" NVCC="sccache nvcc"
fi

# Ubuntu image needs to be built against Ubuntu 20.04 and NIXL Libfabric plugin only supports 22.04 and 24.04
# Ubuntu 20.04 is not supported currently because of old hwloc and broken libnuma package (missing numa pkgconfig)
EFA_FLAG=""
if [ "${ENABLE_EFA}" = "true" ] && [ "$TARGETOS" = "rhel" ]; then
    EFA_FLAG="-Dlibfabric_path=${LIBFABRIC_PREFIX}"
fi

PKG_NAME="nixl-cu${CUDA_MAJOR}"
./contrib/tomlutil.py --wheel-name $PKG_NAME pyproject.toml

meson setup build \
    --prefix="${NIXL_PREFIX}" \
    -Dbuildtype=release \
    -Ducx_path="${UCX_PREFIX}" \
    "${EFA_FLAG}" \
    -Dinstall_headers=true

cd build
ninja
ninja install
cd ..
. ${VIRTUAL_ENV}/bin/activate
python -m build --no-isolation --wheel -o /wheels

cp build/src/bindings/python/nixl-meta/nixl-*-py3-none-any.whl /wheels/

rm -rf build

cd /tmp && rm -rf /tmp/nixl
