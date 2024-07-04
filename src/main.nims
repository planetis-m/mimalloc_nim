import std/[os, strutils]

var useMimalloc = defined(mimalloc) or defined(mimallocDynamic)

# Uncomment this to use mimalloc by default
#useMimalloc = true

if useMimalloc:
  switch("mm", "orc")
  switch("define", "useMalloc")

  when not defined(mimallocDynamic):
    let
      mimallocPath = projectDir() / "mimalloc" 
      # Quote the paths so we support paths with spaces
      # TODO: Is there a better way of doing this?
      mimallocStatic = "mimallocStatic=\"" & (mimallocPath / "src/static.c") & '"'
      mimallocIncludePath = "mimallocIncludePath=\"" & (mimallocPath / "include") & '"'

    # So we can compile mimalloc from the patched files
    switch("define", mimallocStatic)
    switch("define", mimallocIncludePath)

  # Not sure if we really need those or not, but Mimalloc uses them
  case get("cc")
  of "gcc", "clang", "icc", "icl":
    # todo: with musl use local-dynamic for the static build
    switch("passC", "-ftls-model=initial-exec -fno-builtin-malloc")
  else:
    discard

  {.hint: "Patching malloc.nim to use mimalloc".}
  patchFile("stdlib", "malloc", "patchedstd/mimalloc")
