cmake_minimum_required(VERSION 3.20)

if(POLICY CMP0141)
    cmake_policy(SET CMP0141 NEW)
    set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "$<IF:$<AND:$<C_COMPILER_ID:MSVC>,$<CXX_COMPILER_ID:MSVC>>,$<$<CONFIG:Debug,RelWithDebInfo>:EditAndContinue>,$<$<CONFIG:Debug,RelWithDebInfo>:ProgramDatabase>>")
endif()

project(Klang LANGUAGES CXX)

if(MSVC)
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")
    string(REPLACE "/MDd" "" CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG}")
    add_compile_definitions(_ITERATOR_DEBUG_LEVEL=0)
endif()

add_library(k_frontend STATIC
    src/lang/Ast.cpp
    src/lang/AstPrinter.cpp
    src/lang/Diagnostic.cpp
    src/lang/Lexer.cpp
    src/lang/ModuleSystem.cpp
    src/lang/Parser.cpp
    src/lang/Semantic.cpp
    src/lang/SemanticType.cpp
    src/lang/Source.cpp
    src/lang/Token.cpp
)
target_include_directories(k_frontend PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_compile_features(k_frontend PUBLIC cxx_std_20)
set_target_properties(k_frontend PROPERTIES CXX_EXTENSIONS OFF)

find_package(LLVM 22.1.8 EXACT REQUIRED CONFIG)
if(MSVC AND TARGET LLVMDebugInfoPDB)
    find_file(K_DIAGUIDS_LIBRARY diaguids.lib
        HINTS "$ENV{VSINSTALLDIR}DIA SDK/lib/amd64"
        REQUIRED
    )
    get_target_property(K_PDB_LINK_LIBRARIES
        LLVMDebugInfoPDB INTERFACE_LINK_LIBRARIES)
    list(REMOVE_AT K_PDB_LINK_LIBRARIES 0)
    list(PREPEND K_PDB_LINK_LIBRARIES "${K_DIAGUIDS_LIBRARY}")
    set_target_properties(LLVMDebugInfoPDB PROPERTIES
        INTERFACE_LINK_LIBRARIES "${K_PDB_LINK_LIBRARIES}")
endif()
llvm_map_components_to_libnames(K_LLVM_LIBS
    core support target mc codegen native nativecodegen
)

add_library(k_std_runtime STATIC
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

add_library(k_codegen STATIC
    src/codegen/ClangLinker.cpp
    src/codegen/LlvmCodegen.cpp
    src/codegen/NativeEmitter.cpp
)
target_compile_definitions(k_codegen PRIVATE
    K_CONFIGURED_CLANG_PATH="${LLVM_TOOLS_BINARY_DIR}/clang.exe"
    K_STD_RUNTIME_PATH="$<TARGET_FILE:k_std_runtime>"
    K_BOOTSTRAP_RUNTIME_PATH="$<TARGET_FILE:k_bootstrap_runtime>")
target_include_directories(k_codegen PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_include_directories(k_codegen SYSTEM PUBLIC ${LLVM_INCLUDE_DIRS})
target_compile_features(k_codegen PUBLIC cxx_std_20)
target_link_libraries(k_codegen PUBLIC k_frontend PRIVATE ${K_LLVM_LIBS})
set_target_properties(k_codegen PROPERTIES CXX_EXTENSIONS OFF)

add_executable(kc src/cli/main.cpp)
target_link_libraries(kc PRIVATE k_frontend k_codegen)
add_dependencies(kc k_std_runtime k_bootstrap_runtime)

include(CTest)
if(BUILD_TESTING)
    add_executable(k_frontend_tests tests/LexerTests.cpp)
    target_include_directories(k_frontend_tests PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/tests")
    target_link_libraries(k_frontend_tests PRIVATE k_frontend)
    add_test(NAME k_frontend_tests COMMAND k_frontend_tests)

    add_executable(k_parser_tests tests/ParserTests.cpp)
    target_include_directories(k_parser_tests PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/tests")
    target_link_libraries(k_parser_tests PRIVATE k_frontend)
    add_test(NAME k_parser_tests COMMAND k_parser_tests)

    add_executable(k_semantic_tests tests/SemanticTests.cpp)
    target_include_directories(k_semantic_tests PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/tests")
    target_link_libraries(k_semantic_tests PRIVATE k_frontend)
    add_test(NAME k_semantic_tests COMMAND k_semantic_tests)

    add_executable(k_codegen_tests tests/CodegenTests.cpp)
    target_include_directories(k_codegen_tests PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/tests")
    target_include_directories(k_codegen_tests PRIVATE ${LLVM_INCLUDE_DIRS})
    target_link_libraries(k_codegen_tests PRIVATE k_codegen)
    add_test(NAME k_codegen_tests COMMAND k_codegen_tests)


    add_executable(k_native_tests tests/NativeEmitterTests.cpp)
    target_include_directories(k_native_tests PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/tests")
    target_link_libraries(k_native_tests PRIVATE k_codegen)
    add_test(NAME k_native_tests COMMAND k_native_tests)

    add_executable(k_bootstrap_runtime_tests tests/BootstrapRuntimeTests.cpp)
    target_include_directories(k_bootstrap_runtime_tests PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/tests"
        "${CMAKE_CURRENT_SOURCE_DIR}/src")
    target_link_libraries(k_bootstrap_runtime_tests PRIVATE k_bootstrap_runtime)
    add_test(NAME k_bootstrap_runtime_tests COMMAND k_bootstrap_runtime_tests)

    add_executable(k_token_dump tests/TokenDump.cpp)
    target_link_libraries(k_token_dump PRIVATE k_frontend)

    add_executable(k_ast_shape_dump tests/AstShapeDump.cpp)
    target_link_libraries(k_ast_shape_dump PRIVATE k_frontend)

    add_executable(k_semantic_shape_dump tests/SemanticShapeDump.cpp)
    target_link_libraries(k_semantic_shape_dump PRIVATE k_frontend)

    add_test(
        NAME k_bootstrap_container_tests
        COMMAND powershell.exe -NoProfile -ExecutionPolicy Bypass
            -File "${CMAKE_CURRENT_SOURCE_DIR}/tests/BootstrapContainerTests.ps1"
            -Compiler "$<TARGET_FILE:kc>"
            -Token "${CMAKE_CURRENT_SOURCE_DIR}/src/kbootstrap/token.k"
            -Library "${CMAKE_CURRENT_SOURCE_DIR}/src/kbootstrap/containers.k"
            -TestSource "${CMAKE_CURRENT_SOURCE_DIR}/tests/bootstrap/container_tests.k"
            -Output "${CMAKE_CURRENT_BINARY_DIR}/bootstrap-containers-test.exe"
    )

    add_test(
        NAME k_bootstrap_lexer_tests
        COMMAND powershell.exe -NoProfile -ExecutionPolicy Bypass
            -File "${CMAKE_CURRENT_SOURCE_DIR}/tests/BootstrapLexerTests.ps1"
            -Compiler "$<TARGET_FILE:kc>"
            -TokenDump "$<TARGET_FILE:k_token_dump>"
            -SourceModule "${CMAKE_CURRENT_SOURCE_DIR}/src/kbootstrap/source.k"
            -Token "${CMAKE_CURRENT_SOURCE_DIR}/src/kbootstrap/token.k"
            -Containers "${CMAKE_CURRENT_SOURCE_DIR}/src/kbootstrap/containers.k"
            -Lexer "${CMAKE_CURRENT_SOURCE_DIR}/src/kbootstrap/lexer.k"
            -Main "${CMAKE_CURRENT_SOURCE_DIR}/tests/bootstrap/lexer_main.k"
            -Fixture "${CMAKE_CURRENT_SOURCE_DIR}/tests/fixtures/bootstrap-lexer.k"
            -Output "${CMAKE_CURRENT_BINARY_DIR}/bootstrap-lexer-test.exe"
    )

    add_test(
        NAME k_bootstrap_parser_tests
        COMMAND powershell.exe -NoProfile -ExecutionPolicy Bypass
            -File "${CMAKE_CURRENT_SOURCE_DIR}/tests/BootstrapParserTests.ps1"
            -Compiler "$<TARGET_FILE:kc>"
            -AstDump "$<TARGET_FILE:k_ast_shape_dump>"
            -SourceDirectory "${CMAKE_CURRENT_SOURCE_DIR}/src/kbootstrap"
            -Main "${CMAKE_CURRENT_SOURCE_DIR}/tests/bootstrap/parser_main.k"
            -Fixture "${CMAKE_CURRENT_SOURCE_DIR}/tests/fixtures/bootstrap-lexer.k"
            -SecondFixture "${CMAKE_CURRENT_SOURCE_DIR}/tests/fixtures/bootstrap-parser.k"
            -InvalidDirectory "${CMAKE_CURRENT_SOURCE_DIR}/tests/fixtures"
            -Output "${CMAKE_CURRENT_BINARY_DIR}/bootstrap-parser-test.exe"
    )

    add_test(
        NAME k_bootstrap_semantic_tests
        COMMAND powershell.exe -NoProfile -ExecutionPolicy Bypass
            -File "${CMAKE_CURRENT_SOURCE_DIR}/tests/BootstrapSemanticTests.ps1"
            -Compiler "$<TARGET_FILE:kc>"
            -SemanticDump "$<TARGET_FILE:k_semantic_shape_dump>"
            -SourceDirectory "${CMAKE_CURRENT_SOURCE_DIR}/src/kbootstrap"
            -Main "${CMAKE_CURRENT_SOURCE_DIR}/tests/bootstrap/semantic_main.k"
            -FixtureDirectory "${CMAKE_CURRENT_SOURCE_DIR}/tests/fixtures"
            -Output "${CMAKE_CURRENT_BINARY_DIR}/bootstrap-semantic-test.exe"
    )

    add_test(
        NAME k_bootstrap_codegen_tests
        COMMAND powershell.exe -NoProfile -ExecutionPolicy Bypass
            -File "${CMAKE_CURRENT_SOURCE_DIR}/tests/BootstrapCodegenTests.ps1"
            -Compiler "$<TARGET_FILE:kc>"
            -Opt "${LLVM_TOOLS_BINARY_DIR}/opt.exe"
            -Clang "${LLVM_TOOLS_BINARY_DIR}/clang.exe"
            -StdRuntime "$<TARGET_FILE:k_std_runtime>"
            -BootstrapRuntime "$<TARGET_FILE:k_bootstrap_runtime>"
            -SourceDirectory "${CMAKE_CURRENT_SOURCE_DIR}/src/kbootstrap"
            -Fixture "${CMAKE_CURRENT_SOURCE_DIR}/tests/bootstrap/hello.k"
            -FunctionsFixture "${CMAKE_CURRENT_SOURCE_DIR}/tests/bootstrap/functions.k"
            -ControlFlowFixture "${CMAKE_CURRENT_SOURCE_DIR}/tests/bootstrap/control_flow.k"
            -AggregatesFixture "${CMAKE_CURRENT_SOURCE_DIR}/tests/bootstrap/aggregates.k"
            -GenericsFixture "${CMAKE_CURRENT_SOURCE_DIR}/tests/bootstrap/generics.k"
            -MultipleGenericsFixture "${CMAKE_CURRENT_SOURCE_DIR}/tests/bootstrap/generics_multiple.k"
            -GenericNullableFixture "${CMAKE_CURRENT_SOURCE_DIR}/tests/bootstrap/generic_nullable.k"
            -GenericStructsFixture "${CMAKE_CURRENT_SOURCE_DIR}/tests/bootstrap/generic_structs.k"
            -Output "${CMAKE_CURRENT_BINARY_DIR}/bootstrap-codegen-test.exe"
    )

    add_test(
        NAME k_bootstrap_acceptance
        COMMAND powershell.exe -NoProfile -ExecutionPolicy Bypass
            -File "${CMAKE_CURRENT_SOURCE_DIR}/tests/BootstrapAcceptance.ps1"
            -Kc0 "$<TARGET_FILE:kc>"
            -Opt "${LLVM_TOOLS_BINARY_DIR}/opt.exe"
            -Clang "${LLVM_TOOLS_BINARY_DIR}/clang.exe"
            -StdRuntime "$<TARGET_FILE:k_std_runtime>"
            -BootstrapRuntime "$<TARGET_FILE:k_bootstrap_runtime>"
            -SourceDirectory "${CMAKE_CURRENT_SOURCE_DIR}/src/kbootstrap"
            -FixtureDirectory "${CMAKE_CURRENT_SOURCE_DIR}/tests/bootstrap"
            -InvalidFixtureDirectory "${CMAKE_CURRENT_SOURCE_DIR}/tests/fixtures"
            -OutputDirectory "${CMAKE_CURRENT_BINARY_DIR}/bootstrap-acceptance"
    )
endif()
