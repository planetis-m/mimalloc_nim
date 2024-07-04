var useMimalloc = defined(mimalloc) or defined(mimallocDynamic)

# Uncomment this to use mimalloc by default
#useMimalloc = true

if useMimalloc:
  switch("mm", "orc") # arc
  switch("define", "useMalloc")
  {.hint: "Patching malloc.nim to use mimalloc".}
  patchFile("stdlib", "malloc", "patchedstd/mimalloc")
