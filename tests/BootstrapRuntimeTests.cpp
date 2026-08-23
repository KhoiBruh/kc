#include "TestHarness.h"
#include "lib/bootstrap/BootstrapRuntime.h"

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

#include <array>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <string>

TEST(bootstrap_runtime_allocates_and_frees_memory) {
    const auto before = k_boot_live_allocations();
    auto* memory = static_cast<std::uint8_t*>(k_boot_alloc(32));
    EXPECT_TRUE(memory != nullptr);
    if (memory) {
        memory[0] = 42;
        memory[31] = 24;
        EXPECT_EQ(memory[0], std::uint8_t{42});
        EXPECT_EQ(memory[31], std::uint8_t{24});
    }
    k_boot_free(memory);
    EXPECT_EQ(k_boot_live_allocations(), before);
}

TEST(bootstrap_runtime_round_trips_binary_files) {
    const auto path =
        std::filesystem::temp_directory_path() / "klang-bootstrap-runtime.bin";
    std::filesystem::remove(path);
    const auto pathText = path.u8string();
    const std::array<std::uint8_t, 4> expected{0, 1, 0, 255};

    EXPECT_TRUE(k_boot_write_file(
        reinterpret_cast<const std::uint8_t*>(pathText.data()),
        pathText.size(), expected.data(), expected.size()));

    std::uint8_t* actual = nullptr;
    std::uint64_t actualLength = 0;
    EXPECT_TRUE(k_boot_read_file(
        reinterpret_cast<const std::uint8_t*>(pathText.data()),
        pathText.size(), &actual, &actualLength));
    EXPECT_EQ(actualLength, expected.size());
    if (actual && actualLength == expected.size()) {
        for (std::size_t i = 0; i < expected.size(); ++i)
            EXPECT_EQ(actual[i], expected[i]);
    }
    k_boot_free(actual);
    std::filesystem::remove(path);
}

TEST(bootstrap_runtime_returns_utf8_paths) {
    const auto before = k_boot_live_allocations();
    std::uint8_t* current = nullptr;
    std::uint64_t currentLength = 0;
    EXPECT_TRUE(k_boot_current_directory(&current, &currentLength));
    EXPECT_TRUE(current != nullptr);
    EXPECT_TRUE(currentLength != 0);

    const std::string relative{"."};
    std::uint8_t* canonical = nullptr;
    std::uint64_t canonicalLength = 0;
    EXPECT_TRUE(k_boot_canonical_path(
        reinterpret_cast<const std::uint8_t*>(relative.data()), relative.size(),
        &canonical, &canonicalLength));
    EXPECT_EQ(canonicalLength, currentLength);
    if (canonical && current && canonicalLength == currentLength) {
        for (std::uint64_t i = 0; i < currentLength; ++i)
            EXPECT_EQ(canonical[i], current[i]);
    }
    k_boot_free(canonical);
    k_boot_free(current);
    EXPECT_EQ(k_boot_live_allocations(), before);
}

TEST(bootstrap_runtime_rejects_invalid_path_input) {
    std::uint8_t* data = reinterpret_cast<std::uint8_t*>(1);
    std::uint64_t length = 99;
    EXPECT_TRUE(!k_boot_canonical_path(nullptr, 1, &data, &length));
    EXPECT_TRUE(data == nullptr);
    EXPECT_EQ(length, std::uint64_t{0});
}

TEST(bootstrap_runtime_returns_child_process_exit_code) {
    const std::string command{"cmd.exe /d /c exit /b 7"};
    EXPECT_EQ(
        k_boot_run(
            reinterpret_cast<const std::uint8_t*>(command.data()),
            command.size()),
        std::int32_t{7});
}

TEST(bootstrap_runtime_child_stderr_reaches_caller) {
    const auto path = std::filesystem::current_path() /
        "klang-child-stderr-test.txt";
    std::error_code ignored;
    std::filesystem::remove(path, ignored);
    SECURITY_ATTRIBUTES inherit{sizeof(SECURITY_ATTRIBUTES), nullptr, TRUE};
    HANDLE file = CreateFileW(
        path.c_str(), GENERIC_WRITE, FILE_SHARE_READ, &inherit,
        CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    EXPECT_TRUE(file != INVALID_HANDLE_VALUE);
    if (file == INVALID_HANDLE_VALUE) return;
    const HANDLE previous = GetStdHandle(STD_ERROR_HANDLE);
    SetStdHandle(STD_ERROR_HANDLE, file);
    const std::string command{"cmd.exe /d /c echo boom 1>&2"};
    const std::int32_t result = k_boot_run(
        reinterpret_cast<const std::uint8_t*>(command.data()),
        command.size());
    FlushFileBuffers(file);
    SetStdHandle(STD_ERROR_HANDLE, previous);
    CloseHandle(file);
    EXPECT_EQ(result, std::int32_t{0});
    std::ifstream contents(path);
    std::string text{std::istreambuf_iterator<char>{contents},
        std::istreambuf_iterator<char>{}};
    EXPECT_TRUE(text.find("boom") != std::string::npos);
    std::filesystem::remove(path, ignored);
}

TEST(bootstrap_runtime_exposes_command_line_arguments) {
    EXPECT_TRUE(k_boot_arg_count() >= 1);
    std::uint8_t* data = nullptr;
    std::uint64_t length = 0;
    EXPECT_TRUE(k_boot_arg(0, &data, &length));
    EXPECT_TRUE(data != nullptr);
    EXPECT_TRUE(length != 0);
    k_boot_free(data);

    data = reinterpret_cast<std::uint8_t*>(1);
    length = 99;
    EXPECT_TRUE(!k_boot_arg(k_boot_arg_count(), &data, &length));
    EXPECT_TRUE(data == nullptr);
    EXPECT_EQ(length, std::uint64_t{0});
}

TEST(bootstrap_runtime_reports_recoverable_failures) {
    const std::string missingPath{
        "Z:/klang-bootstrap-tests/path-does-not-exist/input.k"};
    std::uint8_t* data = reinterpret_cast<std::uint8_t*>(1);
    std::uint64_t length = 99;
    EXPECT_TRUE(!k_boot_read_file(
        reinterpret_cast<const std::uint8_t*>(missingPath.data()),
        missingPath.size(), &data, &length));
    EXPECT_TRUE(data == nullptr);
    EXPECT_EQ(length, std::uint64_t{0});

    const std::string missingCommand{
        "klang-command-that-does-not-exist.exe"};
    EXPECT_EQ(
        k_boot_run(
            reinterpret_cast<const std::uint8_t*>(missingCommand.data()),
            missingCommand.size()),
        std::int32_t{-1});
}

TEST(bootstrap_runtime_accepts_empty_stderr_write) {
    k_boot_stderr(nullptr, 0);
    EXPECT_TRUE(true);
}

int main() {
    return test::runAll();
}
