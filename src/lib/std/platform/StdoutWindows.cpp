#include "lib/std/platform/Stdout.h"

#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

namespace k::std_runtime {

void writeStdout(const char* bytes, std::uint64_t length) {
    const auto output = GetStdHandle(STD_OUTPUT_HANDLE);
    while (length != 0) {
        const auto chunk = length > MAXDWORD
            ? MAXDWORD : static_cast<DWORD>(length);
        DWORD written = 0;
        if (!WriteFile(output, bytes, chunk, &written, nullptr) || written == 0)
            return;
        bytes += written;
        length -= written;
    }
}

}
