# Package

version       = "0.3.0"
author        = "Antonis Geralis"
description   = "A drop-in solution to use mimalloc in Nim"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 2.0.0"

# Tasks

from std/os import `/`, quoteShell
from std/strutils import find

proc editConfig(dir: string) =
  withDir(dir):
    let filename = "mimalloc/config.nim"
    var content = readFile(filename)
    let name = "patchFile(\"stdlib\", \"malloc\","
    let first = find(content, name)
    content.insert(dir, first + len(name) + len(" r\""))
    writeFile(filename, content)

proc editConstants(dir: string) =
  withDir(dir):
    let filename = "patchedstd/mimalloc.nim"
    var content = readFile(filename)
    for name in ["mimallocStatic", "mimallocIncludePath"]:
      let first = find(content, name)
      content.insert(dir, first + len(name) + len(" = r\""))
    writeFile(filename, content)

after install:
  let dir = thisDir().quoteShell
  # Change the constants
  editConstants(dir)
  # Edit mimalloc/config
  editConfig(dir)

task localInstall, "Install on your local workspace":
  # Works with atlas
  let dir = thisDir().quoteShell / "src"
  editConstants(dir)
  editConfig(dir)

task benchmark, "Run the benchmark":
  localInstallTask()
  exec "nim c -d:release -d:danger --mm:orc -d:useMimalloc benchmark/main.nim"
  exec "./benchmark/main 18"
