#pragma once

#include <cstdint>

extern "C" void k_std_print_bytes(const char* bytes, std::uint64_t length);
extern "C" void k_std_print_i32(std::int32_t value);
