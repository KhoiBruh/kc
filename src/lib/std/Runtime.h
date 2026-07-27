#pragma once

#include <cstddef>
#include <cstdint>

extern "C" void* k_std_alloc(std::uint64_t size);
extern "C" void k_std_free(void* pointer);
extern "C" void k_std_print_bytes(const char* bytes, std::uint64_t length);
extern "C" void k_std_print_i32(std::int32_t value);
