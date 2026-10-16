#!/bin/bash

export TARGET_ARCH=x86

script_path="$(dirname "${BASH_SOURCE[0]}")"

"$script_path/linker.sh" $@