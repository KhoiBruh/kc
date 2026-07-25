#include "TestHarness.h"
#include "lib/bootstrap/BootstrapRuntime.h"

#include <array>
#include <cstdint>
#include <filesystem>
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

TEST(bootstrap_runtime_returns_child_process_exit_code) {
    const std::string command{"cmd.exe /d /c exit /b 7"};
    EXPECT_EQ(
        k_boot_run(
            reinterpret_cast<const std::uint8_t*>(command.data()),
            command.size()),
        std::int32_t{7});
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
