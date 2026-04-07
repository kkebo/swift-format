#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift.org open source project
##
## Copyright (c) 2014 - 2025 Apple Inc. and the Swift project authors
## Licensed under Apache License v2.0 with Runtime Library Exception
##
## See https://swift.org/LICENSE.txt for license information
## See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
##
##===----------------------------------------------------------------------===##

set -euxo pipefail

sudo apt-get update && sudo apt-get install --no-install-recommends -y libcurl4-openssl-dev

curl -O "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz"
tar zxf "swiftly-$(uname -m).tar.gz"
./swiftly init -y --skip-install -n
# shellcheck source=/dev/null
. "$HOME/.local/share/swiftly/env.sh"
hash -r

cat <<EOF >> "$GITHUB_ENV"
PATH=$PATH
SWIFTLY_HOME_DIR=$SWIFTLY_HOME_DIR
SWIFTLY_BIN_DIR=$SWIFTLY_BIN_DIR
SWIFTLY_TOOLCHAINS_DIR=$SWIFTLY_TOOLCHAINS_DIR
EOF
