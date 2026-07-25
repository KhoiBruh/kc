#pragma once

#include <exception>
#include <functional>
#include <iostream>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

namespace test {

struct Case {
    std::string name;
    std::function<void()> body;
};

inline std::vector<Case>& cases() {
    static std::vector<Case> all;
    return all;
}

inline int failures = 0;

struct Registrar {
    Registrar(std::string name, std::function<void()> body) {
        cases().push_back({std::move(name), std::move(body)});
    }
};

inline void fail(const char* file, int line, const std::string& message) {
    ++failures;
    std::cerr << file << ':' << line << ": " << message << '\n';
}

template <typename A, typename B>
void expectEqual(const A& actual, const B& expected, const char* file, int line) {
    if (!(actual == expected)) {
        std::ostringstream message;
        message << "expected equality";
        fail(file, line, message.str());
    }
}

inline int runAll() {
    for (const auto& item : cases()) {
        try {
            item.body();
        } catch (const std::exception& error) {
            fail(__FILE__, __LINE__, item.name + ": " + error.what());
        } catch (...) {
            fail(__FILE__, __LINE__, item.name + ": unknown exception");
        }
    }
    if (failures == 0) {
        std::cout << cases().size() << " tests passed\n";
    }
    return failures == 0 ? 0 : 1;
}

}

#define TEST(name) \
    static void name(); \
    static test::Registrar name##_registrar{#name, name}; \
    static void name()

#define EXPECT_TRUE(condition) \
    do { if (!(condition)) test::fail(__FILE__, __LINE__, "expected " #condition); } while (false)

#define EXPECT_EQ(actual, expected) \
    test::expectEqual((actual), (expected), __FILE__, __LINE__)
