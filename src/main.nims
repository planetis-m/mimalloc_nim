import std/os

var useMimalloc = defined(mimalloc) or defined(mimallocDynamic)

# Uncomment this to use mimalloc by default
#useMimalloc = true

if useMimalloc:
  switch("mm", "orc") # arc
  switch("define", "useMalloc")

  when not defined(mimallocDynamic):
    let
      mimallocPath = projectDir().quoteShell / "mimalloc"
      # There's no better way of doing this.
      mimallocStatic = "mimallocStatic=\"" & (mimallocPath / "src/static.c") & '"'
      mimallocIncludePath = "mimallocIncludePath=\"" & (mimallocPath / "include") & '"'

    # So we can compile mimalloc from the patched files
    switch("define", mimallocStatic)
    switch("define", mimallocIncludePath)

  {.hint: "Patching malloc.nim to use mimalloc".}
  patchFile("stdlib", "malloc", "patchedstd/mimalloc")
