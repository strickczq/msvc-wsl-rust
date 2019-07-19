# MSVC WSL Rust

Cross compile Rust programs to the MSVC Windows target in WSL, inspired by [msvc-wine-rust](https://github.com/est31/msvc-wine-rust)

## Setup environment

### In Windows:

Visit here:

```text
https://visualstudio.microsoft.com/downloads/
```

Then download `Visual Studio` and then install `Desktop development with C++` workload.

Or just download `Build Tools for Visual Studio` and then install `C++ Build Tools` workload.

### In WSL:

First, add `MSVC` targets using `rustup`:

```bash
rustup target add x86_64-pc-windows-msvc 
rustup target add i686-pc-windows-msvc
```

Then, download the script to your WSL home:

```bash
git clone https://github.com/strickczq/msvc-wsl-rust.git msvc-linker
chmod a+x msvc-linker/*.sh
```

Last, edit linker config in `msvc-linker/config.sh`, it may vary from person to person, here is my config:

```bash
#!/bin/bash

# Name of WSL distro
# Find it in "\\wsl$\"
wsl_distro=Arch

# Version of Visual Studio you installed
vs_version=2019

# Version of MSVC tools
# Find it in "C:\Program Files (x86)\Microsoft Visual Studio\$vs_version\BuildTools\VC\Tools\MSVC"
tools_version=14.21.27702

# Version of Windows 10 SDK
# Find it in "C:\Program Files (x86)\Windows Kits\10\Lib"
sdk_version=10.0.17763.0
```

## How to compile

### Compiling by rustc

For x86_64 target:

```bash
rustc -C linker="/path/to/msvc-linker/linker-x64.sh" --target x86_64-pc-windows-msvc your_code.rs
```

For x86 target (Haven't tested yet):

```bash
rustc -C linker="/path/to/msvc-linker/linker-x86.sh" --target i686-pc-windows-msvc your_code.rs
```

### Compiling by cargo

You need to put this into `~/.cargo/config` first:

```toml
[target.x86_64-pc-windows-msvc]
linker = "/path/to/msvc-linker/linker-x64.sh"

[target.i686-pc-windows-mssvc]
linker = "/path/to/msvc-linker/linker-x86.sh"
```

For x86_64 target:

```bash
cargo build --target x86_64-pc-windows-msvc
```

And for x86 target (Haven't tested yet):

```bash
cargo build --target i686-pc-windows-msvc
```

## Test your exe directly in WSL

```bash
chmod a+x your.exe
./your.exe
```

## License
Licensed under Apache License 2.0. For details, see the [LICENSE](LICENSE) file.