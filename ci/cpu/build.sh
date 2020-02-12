#!/bin/bash
# Copyright (c) 2020, NVIDIA CORPORATION.
###############################################################
# rapids/rapids-xgboost meta pkg conda build script for gpuCI #
#                                                             #
# config set in `ci/axis/*.yml`                               #
###############################################################
set -ex

# Set paths
export PATH=/opt/conda/bin:$PATH
export HOME=$WORKSPACE

# Activate base conda env
source activate base

# Print current env vars
env

# Install gpuCI tools
curl -s https://raw.githubusercontent.com/rapidsai/gpuci-tools/master/install.sh | bash
source ~/.bashrc
cd ~

# Fetch pkgs for upload
gpuci_logger "Install anaconda-client..."
conda install -y anaconda-client


# Print diagnostic information
gpuci_logger "Print conda info..."
conda info
conda config --show-sources
conda list --show-channel-urls

function build_pkg {
  # Build pkg
  gpuci_logger "Start conda build for '$CONDA_RECIPE'..."
  conda build -c ${CONDA_USERNAME:-rapidsai-nightly} -c nvidia -c conda-forge --python=${PYTHON_VERSION} ${CONDA_RECIPE)

  # Get output location
  gpuci_logger "Get conda build output..."
  export UPLOADFILE=`conda build -c ${CONDA_USERNAME:-rapidsai-nightly} -c nvidia -c conda-forge --python=${PYTHON_VERSION} ${CONDA_RECIPE) --output`
  test -e ${UPLOADFILE}

  # Check for upload key
  if [ -z "$MY_UPLOAD_KEY" ]; then
    gpuci_logger "No upload key found, env var MY_UPLOAD_KEY not set, skipping upload..."
    return 0
  fi

  # Upload
  gpuci_logger "Upload starting..."
  echo ${UPLOADFILE}
  anaconda -t ${MY_UPLOAD_KEY} upload -u ${CONDA_USERNAME:-rapidsai-nightly} --label main --force ${UPLOADFILE}
  
  # Remove build
  gpuci_logger "Clean up build cache..."
  conda build purge
}

# Start build
build_pkg

# Build default version if current version matches DEFAULT_CUDA_VERSION
if [ "$CUDA_VESION" == "$DEFAULT_CUDA_VERSION" ] ; then
  gpuci_logger "Current CUDA_VERSION '$CUDA_VERSION' is the DEFAULT_CUDA_VERSION, building package again with incremented build number..."
  gpuci_logger "Previous build number '$RAPIDS_OFFSET'"
  export RAPIDS_OFFSET=$((RAPIDS_OFFSET+1))
  gpuci_logger "New build number '$RAPIDS_OFFSET'"
  build_pkg
fi