#include "lib/std/Runtime.h"
#include "lib/std/platform/Stdout.h"

extern "C" void k_std_print_bytes(const char* bytes, std::uint64_t length) {
    k::std_runtime::writeStdout(bytes, length);
}

extern "C" void k_std_print_i32(std::int32_t value) {
    char buffer[11];
    char* end = buffer + sizeof(buffer);
    char* cursor = end;
    const bool negative = value < 0;
    std::uint32_t magnitude = negative
        ? 0u - static_cast<std::uint32_t>(value)
        : static_cast<std::uint32_t>(value);
    do {
        *--cursor = static_cast<char>('0' + magnitude % 10);
        magnitude /= 10;
    } while (magnitude != 0);
    if (negative) *--cursor = '-';
    k::std_runtime::writeStdout(cursor, static_cast<std::uint64_t>(end - cursor));
}
