# mimalloc: A drop-in solution to use mimalloc in Nim

This package provides an easy way to use mimalloc for Nim with ARC/ORC. It includes the necessary configuration and setup to integrate mimalloc into your Nim projects.

## Installation

You can install this package using Nimble:

```
nimble install mimalloc
```

## Usage

To use mimalloc, simply add the following to your project's .nims file:

```nim
when defined(useMimalloc):
  switch("define", "useMalloc")
  {.hint: "Patching malloc.nim to use mimalloc".}
  patchFile("stdlib", "malloc", "$lib/patchedstd/mimalloc")
```

Then, compile your project with the `-d:mimalloc` flag:

```
nim c -d:mimalloc your_file.nim
```

There's also a `-d:mimallocDynamic` flag that makes the program link against mimalloc dynamically.

## Performance
Mimalloc is advertised as having great performance, and that is true. It's especially useful with 
ARC/ORC with threads because currently ARC/ORC can be slower for single-threaded allocation-heavy applications when compiled with `--threads:on` (see [bug #18146](https://github.com/nim-lang/Nim/issues/18146)).

Some results for the code in this benchmark (it's a traditional binarytrees benchmark). Checked with `hyperfine './src/main 18'` on a Ryzen 7 3700X machine:
| Command                                               | Time (min)   |
|-------------------------------------------------------|--------------|
| `-d:danger --mm:refc`                                 | 1.453 s      |
| `-d:danger --mm:refc --threads:on`                    | 1.513 s      |
| `-d:danger --mm:orc` (without Mimalloc)               | 683.0 ms     |
| `-d:danger --mm:orc --threads:on`  (without Mimalloc) | **1.368** s  |
| `-d:danger --mm:orc`  (with Mimalloc)                 | 562.0 ms     |
| `-d:danger --mm:orc --threads:on` (with Mimalloc)     | **597.6** ms |

One advantage of linking Mimalloc statically is that with LTO the compiler can inline memory-allocation code from the allocator itself, resulting in even better performance:
| Command                                                     | Time (min)  |
|-------------------------------------------------------------|-------------|
| `-d:danger --mm:refc --threads:on -d:lto`                   | 1.424 s     |
| `-d:danger --mm:orc -d:lto` (without Mimalloc)              | 609.9 ms    |
| `-d:danger --mm:orc --threads:on -d:lto` (without Mimalloc) | **1.302** s |
| `-d:danger --mm:orc -d:lto` (with Mimalloc)                 | 509.3 ms    |
| `-d:danger --mm:orc --threads:on -d:lto` (with Mimalloc)    | **514.2 ms**|

## Mimalloc Version

This package includes mimalloc v2.1.7 with all the extra files removed (e.g. the bin folder).
If you want to use another mimalloc version, you can replace the `mimalloc` folder in the package with your desired version from https://github.com/microsoft/mimalloc.

## Licensing

This package is licensed under the MIT license (see LICENSE).

The benchmark code in `benchmark/main.nim` comes from [Programming Language Benchmarks](https://github.com/hanabi1224/Programming-Language-Benchmarks/).

Mimalloc itself is also MIT licensed. If you link with it statically, you **must** retain its LICENSE file
(available in `src/mimalloc/LICENSE`) with your program's distribution in some way.
