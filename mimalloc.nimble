# Package

version       = "0.3.1"
author        = "Antonis Geralis"
description   = "A drop-in solution to use mimalloc in Nim"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 2.0.0"

# Tasks

import std/[os, strutils]

proc substituteInFile(filename, replacement: string) =
  var content = readFile(filename)
  content = content.format(replacement)
  writeFile(filename, content)

proc editMimallocConsts(dir: string) =
  withDir(dir):
    substituteInFile("mimalloc/config.nim", dir)
    substituteInFile("patchedstd/mimalloc.nim", dir)

after install:
  let dir = thisDir()
  editMimallocConsts(dir)

task localInstall, "Install on your local workspace":
  # Works with atlas
  let dir = thisDir() / "src"
  editMimallocConsts(dir)

task benchmark, "Run the benchmark":
  # localInstallTask()
  exec "nim c -d:release -d:danger --mm:orc -d:useMimalloc benchmark/main.nim"
  exec "./benchmark/main 18"
