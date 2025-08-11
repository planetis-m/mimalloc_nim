# Address Sanitizer support
when defined(mimallocAsan):
  # Enable ASan tracking
  {.passC: "-DMI_TRACK_ASAN=1".}
  when defined(clang) or defined(gcc):
    # Add ASan compile and link flags
    {.passC: "-fsanitize=address".}
    {.passL: "-fsanitize=address".}
  # Note: The mimalloc library will automatically include <sanitizer/asan_interface.h>
  # when MI_TRACK_ASAN is defined, so we don't need to explicitly include it in Nim

# Thread Sanitizer support (Clang only)
when defined(mimallocTsan):
  when defined(clang):
    # Enable TSan tracking
    {.passC: "-DMI_TSAN=1".}
    # Add TSan compile and link flags
    {.passC: "-fsanitize=thread -g -O1".}
    {.passL: "-fsanitize=thread".}
  else:
    {.error: "Thread Sanitizer is only supported with Clang compiler".}

# Undefined Behavior Sanitizer support (Clang++ only, Debug build only)
when defined(mimallocUbsan):
  # UBSan requires a debug build
  when defined(debug):
    when defined(clang):
      # Enable UBSan tracking
      {.passC: "-DMI_UBSAN=1".}
      # Add UBSan compile and link flags
      {.passC: "-fsanitize=undefined -g -fno-sanitize-recover=undefined".}
      {.passL: "-fsanitize=undefined".}
    else:
      {.error: "Undefined Behavior Sanitizer is only supported with Clang++ compiler".}
  else:
    {.error: "Undefined Behavior Sanitizer requires a debug build".}

# Musl libc support
when defined(mimallocMusl):
  # Enable musl libc support
  {.passC: "-DMI_LIBC_MUSL=1".}
  when defined(clang) or defined(gcc):
    # Use local-dynamic TLS model for musl
    {.passC: "-ftls-model=local-dynamic".}

# shell32 user32 aren't needed for static linking from my testing
when defined(vcc):
  # Specifically for VCC which has different syntax
  # Add debug flag for debug builds, otherwise use release
  when defined(debug):
    {.passC: "/DDEBUG".}
  else:
    {.passC: "/DNDEBUG".}
    {.passC: "/DMI_BUILD_RELEASE".}
  {.passL: "psapi.lib advapi32.lib bcrypt.lib".}
else:
  # Generic GCC-like arguments
  when defined(debug):
    {.passC: "-DDEBUG -fvisibility=hidden".}
  else:
    {.passC: "-DNDEBUG -fvisibility=hidden".}
    {.passC: "-DMI_BUILD_RELEASE".}

  when not defined(cpp) or not defined(mimallocUbsan):
    {.passC: "-Wstrict-prototypes".}
  when defined(gcc) or defined(clang):
    {.passC: "-Wno-unknown-pragmas".}
  when defined(clang):
    {.passC: "-Wno-static-in-inline".}
  # Not sure if we really need those or not, but Mimalloc uses them
  # Only set TLS model if not using musl (musl sets it above)
  when not defined(mimallocMusl):
    {.passC: "-ftls-model=initial-exec".}
  {.passC: "-fno-builtin-malloc".}
  when defined(windows):
    {.passL: "-lpsapi -ladvapi32 -lbcrypt".}
  else:
    {.passL: "-pthread -lrt -latomic".}

const
  mimallocStatic = r"$1/mimalloc/src/static.c"
  mimallocIncludePath = r"$1/mimalloc/include"

{.passC: "-I" & mimallocIncludePath.}
# Compile mimalloc as C++ when using UBSan (matching CMake's MI_USE_CXX behavior)
# force C++ compilation with msvc or clang-cl to use modern C++ atomics
when defined(mimallocUbsan) or defined(vcc) or defined(icc) or defined(clangcl):
  {.compile(mimallocStatic, "-x c++").}
  {.link: "-lstdc++".}
else:
  {.compile: mimallocStatic.}

{.push stackTrace: off.}

proc mi_malloc(size: csize_t): pointer {.importc, header: "mimalloc.h".}
proc mi_calloc(nmemb: csize_t, size: csize_t): pointer {.importc, header: "mimalloc.h".}
proc mi_realloc(pt: pointer, size: csize_t): pointer {.importc, header: "mimalloc.h".}
proc mi_free(p: pointer) {.importc, header: "mimalloc.h".}


proc allocImpl(size: Natural): pointer =
  result = mi_malloc(size.csize_t)
  when defined(zephyr):
    if result == nil:
      raiseOutOfMem()

proc alloc0Impl(size: Natural): pointer =
  result = mi_calloc(size.csize_t, 1)
  when defined(zephyr):
    if result == nil:
      raiseOutOfMem()

proc reallocImpl(p: pointer, newSize: Natural): pointer =
  result = mi_realloc(p, newSize.csize_t)
  when defined(zephyr):
    if result == nil:
      raiseOutOfMem()

proc realloc0Impl(p: pointer, oldSize, newSize: Natural): pointer =
  result = realloc(p, newSize.csize_t)
  if newSize > oldSize:
    zeroMem(cast[pointer](cast[uint](result) + uint(oldSize)), newSize - oldSize)

proc deallocImpl(p: pointer) =
  mi_free(p)


# The shared allocators map on the regular ones

proc allocSharedImpl(size: Natural): pointer =
  allocImpl(size)

proc allocShared0Impl(size: Natural): pointer =
  alloc0Impl(size)

proc reallocSharedImpl(p: pointer, newSize: Natural): pointer =
  reallocImpl(p, newSize)

proc reallocShared0Impl(p: pointer, oldSize, newSize: Natural): pointer =
  realloc0Impl(p, oldSize, newSize)

proc deallocSharedImpl(p: pointer) = deallocImpl(p)


# Empty stubs for the GC

proc GC_disable() = discard
proc GC_enable() = discard

when not defined(gcOrc):
  proc GC_fullCollect() = discard
  proc GC_enableMarkAndSweep() = discard
  proc GC_disableMarkAndSweep() = discard

proc GC_setStrategy(strategy: GC_Strategy) = discard

proc getOccupiedMem(): int = discard
proc getFreeMem(): int = discard
proc getTotalMem(): int = discard

proc nimGC_setStackBottom(theStackBottom: pointer) = discard

proc initGC() = discard

proc newObjNoInit(typ: PNimType, size: int): pointer =
  result = alloc(size)

proc growObj(old: pointer, newSize: int): pointer =
  result = realloc(old, newSize)

proc nimGCref(p: pointer) {.compilerproc, inline.} = discard
proc nimGCunref(p: pointer) {.compilerproc, inline.} = discard

when not defined(gcDestructors):
  proc unsureAsgnRef(dest: PPointer, src: pointer) {.compilerproc, inline.} =
    dest[] = src

proc asgnRef(dest: PPointer, src: pointer) {.compilerproc, inline.} =
  dest[] = src
proc asgnRefNoCycle(dest: PPointer, src: pointer) {.compilerproc, inline,
  deprecated: "old compiler compat".} = asgnRef(dest, src)

type
  MemRegion = object

proc alloc(r: var MemRegion, size: int): pointer =
  result = alloc(size)
proc alloc0Impl(r: var MemRegion, size: int): pointer =
  result = alloc0Impl(size)
proc dealloc(r: var MemRegion, p: pointer) = dealloc(p)
proc deallocOsPages(r: var MemRegion) = discard
proc deallocOsPages() = discard

{.pop.}
