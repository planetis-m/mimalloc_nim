when defined(useMimalloc):
  switch("define", "useMalloc")
  {.hint: "Patching malloc.nim to use mimalloc".}
  patchFile("stdlib", "malloc", r"$1/patchedstd/mimalloc")
