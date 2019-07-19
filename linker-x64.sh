#!/bin/bash

export TARGET_ARCH=x64

script_path="$(dirname "${BASH_SOURCE[0]}")"

"$script_path/linker.sh" $@
