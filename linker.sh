#!/bin/bash

script_path="$(dirname "${BASH_SOURCE[0]}")"
source "$script_path/config.sh"

host=x64
target=${TARGET_ARCH:=x64}

msvc_path="C:\\Program Files (x86)\\Microsoft Visual Studio\\$vs_version\\BuildTools\\VC\\Tools\\MSVC"
kits_path="C:\\Program Files (x86)\\Windows Kits"

linker_exec="$msvc_path\\$tools_version\\bin\\Host$host\\$target\\link.exe"

sdk_libs="$kits_path\\10\\Lib\\$sdk_version\\um\\$target\\"
ucrt_libs="$kits_path\\10\\Lib\\$sdk_version\\ucrt\\$target\\"
crt_libs="$msvc_path\\$tools_version\\lib\\$target\\"

echo "\$env:LIB=\"$sdk_libs;$ucrt_libs;$crt_libs\"" > "$script_path/last-linking.ps1"

path_l2w()
{
        echo "\\\\wsl\$\\$wsl_distro$(echo "$1" | sed "s/\//\\\\/g")"
}

args=""

for v in "$@"; do
        num_of_slash=`tr -dc '/' <<< "$v" | wc -c`
        num_of_colon=`tr -dc ':' <<< "$v" | wc -c`
        if [ "$num_of_slash" -gt "1" ] && [ "$num_of_colon" -eq "0" ]; then
                v="$(path_l2w "$v")"
        fi
        if [ "$num_of_slash" -gt "1" ] && [ "$num_of_colon" -eq "1" ]; then
                v1="$(echo "$v" | cut -d ':' -f 1)"
                v2="$(echo "$v" | cut -d ':' -f 2)"
                v2="$(path_l2w "$v2")"
                v="$v1:$v2"
        fi
        args="$args $v"
done

log_file="$(path_l2w "$script_path/last-linking.log")"

commands_file="$(path_l2w "$script_path/last-linking-args.txt")"
echo "$args" > "$script_path/last-linking-args.txt"

echo "& \"$linker_exec\" \"@$commands_file\" | Out-file \"$log_file\"" >> "$script_path/last-linking.ps1"

mkdir /mnt/c/temp
cp $script_path/last-linking.ps1 /mnt/c/temp
cmd.exe /c "cd C:\temp & powershell.exe -Command .\last-linking.ps1"
