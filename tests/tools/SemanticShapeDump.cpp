#include "lang/Lexer.h"
#include "lang/Parser.h"
#include "lang/Semantic.h"
#include "lang/Source.h"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>

namespace {

unsigned category(const std::string& message) {
    if (message.find("range for does not accept") != std::string::npos)
        return 4;
    if (message.find("duplicate") != std::string::npos) return 1;
    if (message.find("argument count") != std::string::npos ||
        message.find("exactly one argument") != std::string::npos)
        return 3;
    if (message.find("return type") != std::string::npos) return 5;
    if (message.find("condition") != std::string::npos) return 6;
    if (message.find("immutable") != std::string::npos) return 7;
    if (message.find("field") != std::string::npos ||
        message.find("index") != std::string::npos ||
        message.find("member") != std::string::npos)
        return 8;
    if (message.find("unknown") != std::string::npos) return 2;
    return 4;
}

}

int main(int argc, char** argv) {
    if (argc != 2) return 1;
    std::ifstream input{std::filesystem::path{argv[1]}, std::ios::binary};
    if (!input) return 1;
    std::string text{std::istreambuf_iterator<char>{input},
                     std::istreambuf_iterator<char>{}};
    k::Source source{argv[1], std::move(text)};
    const auto lexed = k::Lexer{source}.lexAll();
    if (lexed.error) return 2;
    auto parsed = k::Parser{source, lexed.tokens}.parseProgram();
    if (!parsed.diagnostics.empty()) return 2;
    auto checked = k::SemanticAnalyzer{source, parsed.program}.analyze();
    if (checked.diagnostics.empty()) return 0;
    const auto& diagnostic = checked.diagnostics.front();
    std::cout << category(diagnostic.message) << ':' << diagnostic.span.start
              << ':' << diagnostic.span.end;
    return 2;
}
