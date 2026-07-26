#pragma once

#include <cstdint>

extern "C" {

void* k_boot_alloc(std::uint64_t size);
void k_boot_free(void* pointer);
std::uint64_t k_boot_live_allocations();
std::int32_t k_boot_arg_count();
bool k_boot_arg(
    std::int32_t index,
    std::uint8_t** data,
    std::uint64_t* length);

bool k_boot_read_file(
    const std::uint8_t* path,
    std::uint64_t pathLength,
    std::uint8_t** data,
    std::uint64_t* dataLength);

bool k_boot_current_directory(
    std::uint8_t** data,
    std::uint64_t* dataLength);

bool k_boot_canonical_path(
    const std::uint8_t* path,
    std::uint64_t pathLength,
    std::uint8_t** data,
    std::uint64_t* dataLength);

bool k_boot_write_file(
    const std::uint8_t* path,
    std::uint64_t pathLength,
    const std::uint8_t* data,
    std::uint64_t dataLength);

std::int32_t k_boot_run(
    const std::uint8_t* command,
    std::uint64_t commandLength);

void k_boot_stderr(const std::uint8_t* data, std::uint64_t length);

[[noreturn]] void k_boot_panic(
    const std::uint8_t* data,
    std::uint64_t length);

}
