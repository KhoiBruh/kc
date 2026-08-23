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

add_library(k_codegen STATIC
    src/codegen/ClangLinker.cpp
    src/codegen/LlvmCodegen.cpp
    src/codegen/NativeEmitter.cpp
    src/codegen/Reachability.cpp
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
