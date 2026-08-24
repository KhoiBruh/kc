cmake_minimum_required(VERSION 3.20)

project(Klang LANGUAGES CXX)

if(MSVC)
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")
    string(REPLACE "/MDd" "" CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG}")
    add_compile_definitions(_ITERATOR_DEBUG_LEVEL=0)
endif()

# The C++ reference compiler (kc0) no longer lives on this branch.
# Its sources are preserved on the `kc0-reference` branch and a prebuilt
# binary ships with the `kc0-seed-v0.1` GitHub release. Driver tests below
# use that binary as the bootstrap seed; point KLANG_KC0_EXE at it, e.g.:
#   cmake -DKLANG_KC0_EXE=C:/path/to/kc0.exe ..

set(KLANG_KC0_EXE "" CACHE FILEPATH
    "Path to a kc0 seed binary used by the driver tests")

add_library(k_std_runtime STATIC
    src/lib/std/Allocation.cpp
    src/lib/std/Print.cpp
    src/lib/std/platform/StdoutWindows.cpp
)
target_include_directories(k_std_runtime PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_compile_features(k_std_runtime PUBLIC cxx_std_20)

add_library(k_bootstrap_runtime STATIC
    src/lib/bootstrap/platform/BootstrapWindows.cpp
)
target_include_directories(k_bootstrap_runtime PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_compile_features(k_bootstrap_runtime PUBLIC cxx_std_20)

include(CTest)
if(BUILD_TESTING)
    if(NOT EXISTS "${KLANG_KC0_EXE}")
        message(FATAL_ERROR
            "KLANG_KC0_EXE must point at a kc0 seed binary (download the "
            "kc0-seed-v0.1 release asset or build one from the "
            "kc0-reference branch).")
    endif()

    add_executable(k_bootstrap_runtime_tests tests/unit/BootstrapRuntimeTests.cpp)
    target_include_directories(k_bootstrap_runtime_tests PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/unit"
        "${CMAKE_CURRENT_SOURCE_DIR}/src")
    target_link_libraries(k_bootstrap_runtime_tests PRIVATE k_bootstrap_runtime)
    add_test(NAME k_bootstrap_runtime_tests COMMAND k_bootstrap_runtime_tests)

    add_test(
        NAME k_module_cli_tests
        COMMAND powershell.exe -NoProfile -ExecutionPolicy Bypass
            -File "${CMAKE_CURRENT_SOURCE_DIR}/tests/drivers/ModuleCliTests.ps1"
            -Compiler "${KLANG_KC0_EXE}"
            -Fixture "${CMAKE_CURRENT_SOURCE_DIR}/tests/fixtures/modules/diamond/main.k"
            -Output "${CMAKE_CURRENT_BINARY_DIR}/module-diamond.exe"
    )

    add_test(
        NAME k_bootstrap_container_tests
        COMMAND powershell.exe -NoProfile -ExecutionPolicy Bypass
            -File "${CMAKE_CURRENT_SOURCE_DIR}/tests/drivers/BootstrapContainerTests.ps1"
            -Compiler "${KLANG_KC0_EXE}"
            -Token "${CMAKE_CURRENT_SOURCE_DIR}/src/bootstrap/token.k"
            -List "${CMAKE_CURRENT_SOURCE_DIR}/src/bootstrap/list.k"
            -Library "${CMAKE_CURRENT_SOURCE_DIR}/src/bootstrap/containers.k"
            -TestSource "${CMAKE_CURRENT_SOURCE_DIR}/tests/harness/container_tests.k"
            -Output "${CMAKE_CURRENT_BINARY_DIR}/bootstrap-containers-test.exe"
    )

    add_test(
        NAME k_bootstrap_acceptance
        COMMAND powershell.exe -NoProfile -ExecutionPolicy Bypass
            -File "${CMAKE_CURRENT_SOURCE_DIR}/tests/drivers/BootstrapAcceptance.ps1"
            -Kc0 "${KLANG_KC0_EXE}"
            -Opt "C:/LLVM/bin/opt.exe"
            -Clang "C:/LLVM/bin/clang.exe"
            -StdRuntime "$<TARGET_FILE:k_std_runtime>"
            -BootstrapRuntime "$<TARGET_FILE:k_bootstrap_runtime>"
            -SourceDirectory "${CMAKE_CURRENT_SOURCE_DIR}/src/bootstrap"
            -FixtureDirectory "${CMAKE_CURRENT_SOURCE_DIR}/tests/cases"
            -InvalidFixtureDirectory "${CMAKE_CURRENT_SOURCE_DIR}/tests/fixtures"
            -OutputDirectory "${CMAKE_CURRENT_BINARY_DIR}/bootstrap-acceptance"
    )

    add_test(
        NAME k_differential_tests
        COMMAND powershell.exe -NoProfile -ExecutionPolicy Bypass
            -File "${CMAKE_CURRENT_SOURCE_DIR}/tests/drivers/DifferentialTests.ps1"
            -Kc0 "${KLANG_KC0_EXE}"
            -Opt "C:/LLVM/bin/opt.exe"
            -Clang "C:/LLVM/bin/clang.exe"
            -StdRuntime "$<TARGET_FILE:k_std_runtime>"
            -BootstrapRuntime "$<TARGET_FILE:k_bootstrap_runtime>"
            -SourceDirectory "${CMAKE_CURRENT_SOURCE_DIR}/src/bootstrap"
            -CasesDirectory "${CMAKE_CURRENT_SOURCE_DIR}/tests/cases"
            -OutputDirectory "${CMAKE_CURRENT_BINARY_DIR}/differential"
    )
endif()
