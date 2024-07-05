# Package

version       = "0.2.0"
author        = "Antonis Geralis"
description   = "A Nim package for using mimalloc with ARC/ORC"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 2.0.0"

# Tasks

task benchmark, "Run the benchmark":
  exec "nim c -d:release -d:danger --mm:orc -d:mimalloc benchmark/main.nim"
  exec "./benchmark/main 18"

from std/os import `/`, quoteShell
from std/strutils import find
import std/compilesettings

proc editConstants(dir: string) =
  withDir(dir):
    let filename = "patchedstd/mimalloc.nim"
    var content = readFile(filename)
    for name in ["mimallocStatic", "mimallocIncludePath"]:
      let first = find(content, name)
      content.insert(dir, first + len(name) + len(" = r\""))
    writeFile(filename, content)

# before install:
#   # Works with atlas
#   editConstants(thisDir().quoteShell / "src")

after install:
  # Change the constants
  editConstants(thisDir().quoteShell)
  # Copy mimalloc.nim to the stdlib
  let stdlibDir = querySetting(libPath)
  mkDir(stdlibDir / "patchedstd")
  cpFile("patchedstd/mimalloc.nim", stdlibDir / "patchedstd/mimalloc.nim")
