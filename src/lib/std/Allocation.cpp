#include "lib/std/Runtime.h"

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

#include <cstdint>
#include <limits>

extern "C" void* k_std_alloc(std::uint64_t size) {
    if (size > static_cast<std::uint64_t>(
                   std::numeric_limits<SIZE_T>::max()))
        return nullptr;
    const auto allocationSize =
        static_cast<SIZE_T>(size == 0 ? 1 : size);
    return HeapAlloc(GetProcessHeap(), 0, allocationSize);
}

extern "C" void k_std_free(void* pointer) {
    if (pointer) HeapFree(GetProcessHeap(), 0, pointer);
}
