FROM quay.io/ascend/cann:9.2.0-950-ubuntu22.04-py3.12-devel

ARG BASEDIR=/usr/local
WORKDIR ${BASEDIR}
RUN apt install -y clang-15 lld-15 ccache

ARG LLVM_INSTALL_PREFIX=${BASEDIR}/llvm-install

# Install the dependent PIP packages of our main project.
RUN git clone -b feature/megakernel https://gitcode.com/Ascend/Triton-distributed-ascend.git \
    && cd Triton-distributed-ascend \
    && PYTHONPATH= pip3 install -r requirements.txt \
       --extra-index-url https://download.pytorch.org/whl/cpu \
    && pip3 install ninja


# Build & install LLVM.
# The Triton-ascend component relies on LLVM-specific versions.
# Check out the specified version of LLVM.
RUN git clone --no-checkout https://github.com/llvm/llvm-project.git \
    && cd llvm-project \
    && git checkout f6ded0be897e2878612dd903f7e8bb85448269e5 \
    && wget https://raw.githubusercontent.com/triton-lang/triton-ascend/2e69438a0a41a00ab72c7d46b44d97092cf2362c/third_party/ascend/patch/llvm_patch_f6ded0b.patch \
    && git apply llvm_patch_f6ded0b.patch \
    && mkdir build \
    && cd build \
    && cmake ../llvm \
      -G Ninja \
      -DCMAKE_C_COMPILER=/usr/bin/clang-15 \
      -DCMAKE_CXX_COMPILER=/usr/bin/clang++-15 \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLVM_ENABLE_ASSERTIONS=ON \
      -DLLVM_ENABLE_PROJECTS="mlir;llvm;lld" \
      -DLLVM_TARGETS_TO_BUILD="host;NVPTX;AMDGPU" \
      -DLLVM_USE_LINKER=lld-15 \
      -DCMAKE_INSTALL_PREFIX=${LLVM_INSTALL_PREFIX} \
    && ninja install \
    && cp bin/FileCheck ${LLVM_INSTALL_PREFIX}/bin/FileCheck \
    && cp bin/llvm-lit ${LLVM_INSTALL_PREFIX}/bin/llvm-lit


# Update the version of CMake.
RUN apt update \
    && apt install -y --no-install-recommends ca-certificates gpg wget \
    && wget -qO /tmp/kitware-key.asc \
       https://apt.kitware.com/keys/kitware-archive-latest.asc \
    && gpg --dearmor -o /usr/share/keyrings/kitware.gpg /tmp/kitware-key.asc \
    && echo "deb [signed-by=/usr/share/keyrings/kitware.gpg] https://apt.kitware.com/ubuntu/ jammy main" \
       > /etc/apt/sources.list.d/kitware.list \
    && apt update \
    && apt install -y --no-install-recommends cmake \
    && cmake --version


# Build and install AscendNPU-IR.
RUN git clone https://gitcode.com/Ascend/AscendNPU-IR.git \
    && cd AscendNPU-IR \
    # Check out a specific commit that is known to have compiled. \
    && git checkout af366381db32f9c4c73521a2fe54647bf77e0614 \
    && git submodule update --init --recursive \
    && mkdir build \
    && ./build-tools/build.sh -o ./build -t \
        --build-type Release \
        --apply-patches \
        --bisheng-compiler=${ASCEND_HOME_PATH}/bin \
        --build-shmem-template \
        --c-compiler /usr/bin/clang-15 \
        --cxx-compiler /usr/bin/clang++-15 \
        --add-cmake-options '-DLLVM_USE_LINKER=lld-15'


# Install the zlib compression library.
RUN apt-get update \
    && apt-get install -y --no-install-recommends zlib1g-dev


# Finally, time to build and install the main project.
RUN cd Triton-distributed-ascend \
    && git submodule update --init --recursive \
    && cd 3rdparty/triton-ascend \
    && git submodule update --init --recursive

RUN cd Triton-distributed-ascend/3rdparty/shmem \
    && bash scripts/build.sh -python_extension -soc_type Ascend950 \
    && pip install dist/cann_shmem-*.whl

# WORKAROUND: Patch /usr/local/Triton-distributed-ascend/CMakeLists.txt
# (the top-level project file, NOT a CMakeLists.txt inside triton-ascend).
# Its TRITON_USE_ASCEND branch omits the NVIDIA/AMD header include directories.
# Proton's compiler dialect still builds with TRITON_BUILD_PROTON=OFF and needs
# these headers (PTXAsmFormat.h and TargetUtils.h) from the nested triton-ascend.
# Insert the missing paths in that branch; fail if the expected anchor changes.
# Keep this patch here so the earlier LLVM/AscendNPU-IR layers remain cacheable.
RUN cd Triton-distributed-ascend \
    && test "$(grep -Fxc '  include_directories(${PROJECT_SOURCE_DIR}/3rdparty/triton-ascend/third_party/ascend/include)' CMakeLists.txt)" -eq 1 \
    && sed -i '\|/3rdparty/triton-ascend/third_party/ascend/include)|a\  include_directories(${PROJECT_SOURCE_DIR}/3rdparty/triton-ascend/third_party/nvidia/include)\n  include_directories(${PROJECT_SOURCE_DIR}/3rdparty/triton-ascend/third_party/amd/include)' CMakeLists.txt

# Make this installation an "editable install".
# 2026-10-20: Disable the build Triton-distributed-ascend.
# We'll just have a container that the user must supply his/her own
# Triton-distributed-ascend source code to build.
# RUN cd Triton-distributed-ascend \
#     && PATH="/usr/lib/llvm-15/bin:$PATH" \
#         LLVM_SYSPATH=${LLVM_INSTALL_PREFIX} \
#         TRITON_BUILD_WITH_CLANG_LLD=ON \
#         TRITON_BUILD_PROTON=OFF\
#         TRITON_BUILD_LITTLE_KERNEL=OFF \
#         pip install -e ./python --verbose --no-build-isolation

# Install a few convenient tools.
RUN apt install -y less bc ssh psmisc

# Add the path to the AscendNPU-IR compiler to our PATH environment variable.
ENV PATH=${BASEDIR}/AscendNPU-IR/build/bin:/usr/local/llvm-install/bin:/usr/lib/llvm-15/bin:$PATH
