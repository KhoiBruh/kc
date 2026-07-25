#include "lib/bootstrap/BootstrapRuntime.h"

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

#include <algorithm>
#include <cstdint>
#include <limits>
#include <optional>
#include <string>
#include <vector>

namespace {

std::uint64_t liveAllocations = 0;

std::vector<std::wstring> commandLineArguments() {
    std::vector<std::wstring> arguments;
    const wchar_t* cursor = GetCommandLineW();
    while (*cursor) {
        while (*cursor == L' ' || *cursor == L'\t') ++cursor;
        if (!*cursor) break;
        std::wstring argument;
        bool quoted = false;
        while (*cursor && (quoted || (*cursor != L' ' && *cursor != L'\t'))) {
            std::size_t backslashes = 0;
            while (*cursor == L'\\') {
                ++backslashes;
                ++cursor;
            }
            if (*cursor == L'"') {
                argument.append(backslashes / 2, L'\\');
                if (backslashes % 2 == 0)
                    quoted = !quoted;
                else
                    argument.push_back(L'"');
                ++cursor;
            } else {
                argument.append(backslashes, L'\\');
                if (*cursor) argument.push_back(*cursor++);
            }
        }
        arguments.push_back(std::move(argument));
    }
    return arguments;
}

std::optional<std::wstring> widen(
    const std::uint8_t* text,
    std::uint64_t length) {
    if (length == 0) return std::wstring{};
    if (!text ||
        length > static_cast<std::uint64_t>(std::numeric_limits<int>::max()))
        return std::nullopt;
    const auto* bytes = reinterpret_cast<const char*>(text);
    const auto inputLength = static_cast<int>(length);
    const int required = MultiByteToWideChar(
        CP_UTF8, MB_ERR_INVALID_CHARS, bytes, inputLength, nullptr, 0);
    if (required == 0) return std::nullopt;
    std::wstring result(static_cast<std::size_t>(required), L'\0');
    if (MultiByteToWideChar(
            CP_UTF8, MB_ERR_INVALID_CHARS, bytes, inputLength,
            result.data(), required) != required)
        return std::nullopt;
    if (result.find(L'\0') != std::wstring::npos) return std::nullopt;
    return result;
}

bool writeHandle(
    HANDLE handle,
    const std::uint8_t* data,
    std::uint64_t length) {
    if (length != 0 && !data) return false;
    std::uint64_t written = 0;
    while (written < length) {
        const auto chunk = static_cast<DWORD>(std::min<std::uint64_t>(
            length - written, std::numeric_limits<DWORD>::max()));
        DWORD current = 0;
        if (!WriteFile(handle, data + written, chunk, &current, nullptr) ||
            current == 0)
            return false;
        written += current;
    }
    return true;
}

}

extern "C" void* k_boot_alloc(std::uint64_t size) {
    if (size > static_cast<std::uint64_t>(
                   std::numeric_limits<SIZE_T>::max()))
        return nullptr;
    const auto allocationSize =
        static_cast<SIZE_T>(size == 0 ? 1 : size);
    void* pointer = HeapAlloc(GetProcessHeap(), 0, allocationSize);
    if (pointer) ++liveAllocations;
    return pointer;
}

extern "C" void k_boot_free(void* pointer) {
    if (pointer && HeapFree(GetProcessHeap(), 0, pointer))
        --liveAllocations;
}

extern "C" std::uint64_t k_boot_live_allocations() {
    return liveAllocations;
}

extern "C" std::int32_t k_boot_arg_count() {
    return static_cast<std::int32_t>(commandLineArguments().size());
}

extern "C" bool k_boot_arg(
    std::int32_t index,
    std::uint8_t** data,
    std::uint64_t* length) {
    if (!data || !length) return false;
    *data = nullptr;
    *length = 0;
    const auto arguments = commandLineArguments();
    if (index < 0 || static_cast<std::size_t>(index) >= arguments.size())
        return false;
    const auto& argument = arguments[static_cast<std::size_t>(index)];
    const int wideLength = static_cast<int>(argument.size());
    const int required = WideCharToMultiByte(
        CP_UTF8, WC_ERR_INVALID_CHARS, argument.data(), wideLength,
        nullptr, 0, nullptr, nullptr);
    if (required == 0) return wideLength == 0;
    const auto byteLength = static_cast<std::uint64_t>(required);
    auto* bytes = static_cast<std::uint8_t*>(k_boot_alloc(byteLength));
    if (!bytes) return false;
    const int converted = WideCharToMultiByte(
        CP_UTF8, WC_ERR_INVALID_CHARS, argument.data(), wideLength,
        reinterpret_cast<char*>(bytes), required,
        nullptr, nullptr);
    if (converted != required) {
        k_boot_free(bytes);
        return false;
    }
    *data = bytes;
    *length = byteLength;
    return true;
}

extern "C" bool k_boot_read_file(
    const std::uint8_t* path,
    std::uint64_t pathLength,
    std::uint8_t** data,
    std::uint64_t* dataLength) {
    if (!data || !dataLength) return false;
    *data = nullptr;
    *dataLength = 0;
    const auto widePath = widen(path, pathLength);
    if (!widePath) return false;
    const HANDLE file = CreateFileW(
        widePath->c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
        OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return false;

    LARGE_INTEGER size{};
    if (!GetFileSizeEx(file, &size) || size.QuadPart < 0) {
        CloseHandle(file);
        return false;
    }
    const auto length = static_cast<std::uint64_t>(size.QuadPart);
    auto* buffer = length == 0
        ? nullptr
        : static_cast<std::uint8_t*>(k_boot_alloc(length));
    if (length != 0 && !buffer) {
        CloseHandle(file);
        return false;
    }

    std::uint64_t read = 0;
    while (read < length) {
        const auto chunk = static_cast<DWORD>(std::min<std::uint64_t>(
            length - read, std::numeric_limits<DWORD>::max()));
        DWORD current = 0;
        if (!ReadFile(file, buffer + read, chunk, &current, nullptr) ||
            current == 0) {
            k_boot_free(buffer);
            CloseHandle(file);
            return false;
        }
        read += current;
    }
    CloseHandle(file);
    *data = buffer;
    *dataLength = length;
    return true;
}

extern "C" bool k_boot_write_file(
    const std::uint8_t* path,
    std::uint64_t pathLength,
    const std::uint8_t* data,
    std::uint64_t dataLength) {
    const auto widePath = widen(path, pathLength);
    if (!widePath) return false;
    const HANDLE file = CreateFileW(
        widePath->c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return false;
    const bool success = writeHandle(file, data, dataLength);
    const bool closed = CloseHandle(file) != FALSE;
    return success && closed;
}

extern "C" std::int32_t k_boot_run(
    const std::uint8_t* command,
    std::uint64_t commandLength) {
    auto wideCommand = widen(command, commandLength);
    if (!wideCommand || wideCommand->empty()) return -1;
    std::vector<wchar_t> commandLine(
        wideCommand->begin(), wideCommand->end());
    commandLine.push_back(L'\0');

    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    PROCESS_INFORMATION process{};
    if (!CreateProcessW(
            nullptr, commandLine.data(), nullptr, nullptr, FALSE,
            CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process))
        return -1;
    const DWORD waitResult = WaitForSingleObject(process.hProcess, INFINITE);
    DWORD exitCode = std::numeric_limits<DWORD>::max();
    const bool readExit =
        waitResult == WAIT_OBJECT_0 &&
        GetExitCodeProcess(process.hProcess, &exitCode) != FALSE;
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    return readExit ? static_cast<std::int32_t>(exitCode) : -1;
}

extern "C" void k_boot_stderr(
    const std::uint8_t* data,
    std::uint64_t length) {
    const HANDLE handle = GetStdHandle(STD_ERROR_HANDLE);
    if (handle == nullptr || handle == INVALID_HANDLE_VALUE) return;
    writeHandle(handle, data, length);
}

extern "C" [[noreturn]] void k_boot_panic(
    const std::uint8_t* data,
    std::uint64_t length) {
    k_boot_stderr(data, length);
    ExitProcess(2);
}
