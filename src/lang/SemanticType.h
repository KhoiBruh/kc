#pragma once

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace k {

enum class SemanticTypeKind {
    Error,
    Unit,
    Bool,
    Char,
    String,
    I8,
    I16,
    I32,
    I64,
    I128,
    U8,
    U16,
    U32,
    U64,
    U128,
    F8,
    F16,
    F32,
    F64,
    Pointer,
    Struct,
    Enum,
    Nullable,
    Array,
    Slice,
    NullLiteral,
    TypeParameter,
};

enum class ArraySizeKind {
    Known,
    Inferred,
    Runtime,
};

struct SemanticType {
    SemanticTypeKind kind = SemanticTypeKind::Error;
    std::shared_ptr<const SemanticType> element;
    ArraySizeKind arraySizeKind = ArraySizeKind::Known;
    std::uint64_t knownArraySize = 0;
    std::string name;
    std::vector<SemanticType> typeArguments;
    std::uint32_t typeParameterIndex = 0;

    bool operator==(const SemanticType& other) const;
};

SemanticType nullableType(SemanticType element);
SemanticType pointerType(SemanticType pointee);
SemanticType structType(
    std::string name,
    std::vector<SemanticType> typeArguments = {});
SemanticType enumType(std::string name);
SemanticType arrayType(SemanticType element, std::uint64_t size);
SemanticType inferredArrayType(SemanticType element);
SemanticType runtimeArrayType(SemanticType element);
SemanticType sliceType(SemanticType element);

std::string semanticTypeName(const SemanticType& type);
bool isInteger(const SemanticType& type);
bool isFloat(const SemanticType& type);
bool isNumeric(const SemanticType& type);
std::uint32_t numericBitWidth(const SemanticType& type);
bool isSignedInteger(const SemanticType& type);

}
