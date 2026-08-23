#include "lang/Lexer.h"
#include "lang/Source.h"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>

int main(int argc, char** argv) {
    if (argc != 2) return 1;
    std::ifstream input{std::filesystem::path{argv[1]}, std::ios::binary};
    if (!input) return 1;
    std::string text{
        std::istreambuf_iterator<char>{input},
        std::istreambuf_iterator<char>{}};
    k::Source source{argv[1], std::move(text)};
    const auto result = k::Lexer{source}.lexAll();
    if (result.error) return 2;
    for (const auto& token : result.tokens) {
        std::cout << static_cast<int>(token.kind) << ':'
                  << token.span.start << ':' << token.span.end << ';';
    }
    return 0;
}
