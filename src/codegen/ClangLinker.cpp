#include "codegen/ClangLinker.h"

#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

#include <string>
#include <system_error>

namespace k {
namespace {

std::wstring quote(const std::filesystem::path& path) {
    return L"\"" + path.wstring() + L"\"";
}

}

std::filesystem::path configuredClangPath() {
    return K_CONFIGURED_CLANG_PATH;
}

ClangLinker::ClangLinker(std::filesystem::path clangPath)
    : clangPath_{std::move(clangPath)} {}

LinkResult ClangLinker::link(
    const std::filesystem::path& objectPath,
    const std::filesystem::path& executablePath) const {
    LinkResult result;
    if (!std::filesystem::exists(clangPath_)) {
        result.diagnostics.push_back({"cannot find Clang driver", {0, 0}});
        return result;
    }
    if (!std::filesystem::exists(objectPath)) {
        result.diagnostics.push_back({"cannot find object file", {0, 0}});
        return result;
    }
    auto temporary = executablePath;
    temporary += ".tmp.exe";
    std::wstring command =
        quote(clangPath_) + L" " + quote(objectPath) + L" " +
        quote(K_STD_RUNTIME_PATH) + L" " +
        quote(K_BOOTSTRAP_RUNTIME_PATH) + L" -o " + quote(temporary);
    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    PROCESS_INFORMATION process{};
    if (!CreateProcessW(
            nullptr, command.data(), nullptr, nullptr, FALSE, 0,
            nullptr, nullptr, &startup, &process)) {
        result.diagnostics.push_back({"failed to start Clang driver", {0, 0}});
        return result;
    }
    WaitForSingleObject(process.hProcess, INFINITE);
    DWORD exitCode{};
    GetExitCodeProcess(process.hProcess, &exitCode);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    if (exitCode != 0) {
        result.diagnostics.push_back(
            {"Clang linker failed with exit code " + std::to_string(exitCode), {0, 0}});
        return result;
    }
    std::error_code error;
    std::filesystem::remove(executablePath, error);
    error.clear();
    std::filesystem::rename(temporary, executablePath, error);
    if (error)
        result.diagnostics.push_back(
            {"cannot publish executable: " + error.message(), {0, 0}});
    return result;
}

}
