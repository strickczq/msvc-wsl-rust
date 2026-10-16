#!/bin/bash

# script_path="$(dirname "${BASH_SOURCE[0]}")"
script_path="$(realpath "${BASH_SOURCE[0]}")"
script_path="$(dirname "${script_path}")"

source "$script_path/config.sh"

host=x64

# 대상 아키텍처. linker-x86.sh, linker-x64.sh가 TARGET_ARCH를 정해 주지 않으면(예: PATH의 link.exe로
# 불렸을 때) rustc가 넘긴 오브젝트 파일의 COFF machine 값으로 정한다.
coff_arch()
{
        local machine
        machine="$(od -An -tx2 -N2 "$1" 2>/dev/null | tr -d ' ')"
        # bigobj 형식은 첫 2바이트가 0이고 machine 값이 6바이트 뒤에 있다.
        if [ "$machine" = "0000" ]; then
                machine="$(od -An -tx2 -j6 -N2 "$1" 2>/dev/null | tr -d ' ')"
        fi
        case "$machine" in
                014c) echo x86 ;;
                8664) echo x64 ;;
                aa64) echo arm64 ;;
        esac
}

if [ -z "$TARGET_ARCH" ]; then
        for v in "$@"; do
                case "$v" in
                        *.o|*.obj) [ -f "$v" ] && TARGET_ARCH="$(coff_arch "$v")" ;;
                esac
                [ -n "$TARGET_ARCH" ] && break
        done
fi
if [ -z "$TARGET_ARCH" ]; then
        echo "linker.sh: 오브젝트 파일에서 대상 아키텍처를 알아내지 못했다. TARGET_ARCH=x86|x64|arm64로 지정한다." >&2
        exit 1
fi
target=$TARGET_ARCH

msvc_path="C:\\Program Files (x86)\\Microsoft Visual Studio\\$vs_version\\BuildTools\\VC\\Tools\\MSVC"
kits_path="C:\\Program Files (x86)\\Windows Kits"

linker_exec="$msvc_path\\$tools_version\\bin\\Host$host\\$target\\link.exe"

sdk_libs="$kits_path\\10\\Lib\\$sdk_version\\um\\$target\\"
ucrt_libs="$kits_path\\10\\Lib\\$sdk_version\\ucrt\\$target\\"
crt_libs="$msvc_path\\$tools_version\\lib\\$target\\"

# 실행마다 작업 directory를 따로 쓴다. cargo는 여러 binary를 동시에 link하므로, 고정된 이름의
# 파일을 쓰면 서로의 명령과 인자를 덮어쓴다. 끝나면 last-linking.* 로 옮겨 마지막 기록을 남긴다.
work_dir="$(mktemp -d "$script_path/linking.XXXXXX")" || exit 1
script_file="$work_dir/linking.ps1"
args_file="$work_dir/linking-args.txt"
log_file_local="$work_dir/linking.log"

echo "\$env:LIB=\"$sdk_libs;$ucrt_libs;$crt_libs\"" > "$script_file"
# /MANIFEST:EMBED 등에서 link.exe가 부르는 mt.exe, rc.exe는 Windows SDK의 bin 디렉터리에 있다.
echo "\$env:PATH=\"$kits_path\\10\\bin\\$sdk_version\\$host;\$env:PATH\"" >> "$script_file"

path_l2w()
{
        echo "\\\\wsl\$\\$wsl_distro$(echo "$1" | sed "s/\//\\\\/g")"
}

args=""
# rustc가 /OUT: 으로 넘긴 결과물의 Linux 경로. link 뒤에 실행 권한을 주는 데 쓴다.
output_file=""
# /MANIFESTINPUT: 으로 받은 매니페스트의 Linux 경로. 응답 파일에 넣지 않고 따로 넘긴다.
manifest_inputs=()

for v in "$@"; do
        case "$v" in
                /OUT:*) output_file="${v#/OUT:}" ;;
        esac
        if [[ "${v^^}" == /MANIFESTINPUT:* ]]; then
                manifest_inputs+=("${v#*:}")
                continue
        fi
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

log_file="$(path_l2w "$log_file_local")"

commands_file="$(path_l2w "$args_file")"
echo "$args" > "$args_file"

# link.exe는 \\wsl$ 경로의 매니페스트를 mt.exe에 넘길 때 앞에 \\?\ 를 잘못 붙여 mt.exe가 파일을
# 읽지 못한다. 그래서 매니페스트를 Windows 쪽 임시 디렉터리에 복사해 로컬 경로로 넘긴다.
manifest_args=""
if [ "${#manifest_inputs[@]}" -gt 0 ]; then
        echo '$manifest_dir = Join-Path $env:TEMP ("msvc-linker-" + [guid]::NewGuid())' >> "$script_file"
        echo 'New-Item -ItemType Directory $manifest_dir | Out-Null' >> "$script_file"
        i=0
        for m in "${manifest_inputs[@]}"; do
                name="$i-$(basename "$m")"
                echo "Copy-Item -LiteralPath '$(path_l2w "$m")' \"\$manifest_dir\\$name\"" >> "$script_file"
                manifest_args="$manifest_args \"/MANIFESTINPUT:\$manifest_dir\\$name\""
                i=$((i + 1))
        done
fi

echo "& \"$linker_exec\" \"@$commands_file\"$manifest_args | Out-file \"$log_file\"" >> "$script_file"
# link.exe 종료코드를 powershell 프로세스 종료코드로 전파한다.
# (네이티브 명령을 Out-File로 파이프해도 $LASTEXITCODE 에는 link.exe 의 종료코드가 남는다.)
echo '$status = $LASTEXITCODE' >> "$script_file"
if [ "${#manifest_inputs[@]}" -gt 0 ]; then
        echo 'Remove-Item -Recurse -Force $manifest_dir' >> "$script_file"
fi
echo 'exit $status' >> "$script_file"

powershell.exe -ExecutionPolicy Bypass -Command "$script_file"
status=$?

# link.exe는 Windows 쪽에서 파일을 만들어 Linux 실행 권한 bit가 없다. WSL에서 결과물을 바로
# 실행할 수 있도록 권한을 준다. 실패해도 link 결과는 바꾸지 않는다.
if [ "$status" -eq 0 ] && [ -n "$output_file" ] && [ -f "$output_file" ]; then
        chmod +x "$output_file" 2>/dev/null
fi

# 마지막 link의 기록을 고정된 이름으로 남기고 작업 directory를 치운다.
mv -f "$script_file" "$script_path/last-linking.ps1" 2>/dev/null
mv -f "$args_file" "$script_path/last-linking-args.txt" 2>/dev/null
[ -f "$log_file_local" ] && mv -f "$log_file_local" "$script_path/last-linking.log" 2>/dev/null
rmdir "$work_dir" 2>/dev/null

# powershell(=link.exe)의 종료코드를 래퍼의 종료코드로 전파 → 링크 실패 시 rustc/cargo 가 인지한다.
exit $status
