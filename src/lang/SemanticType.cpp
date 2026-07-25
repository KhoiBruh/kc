#include "lang/SemanticType.h"

#include <utility>

namespace k {
namespace {

SemanticType aggregate(
    SemanticTypeKind kind,
    SemanticType element,
    ArraySizeKind sizeKind = ArraySizeKind::Known,
    std::uint64_t size = 0) {
    return {kind, std::make_shared<SemanticType>(std::move(element)), sizeKind, size};
}

}

bool SemanticType::operator==(const SemanticType& other) const {
    if (kind != other.kind || arraySizeKind != other.arraySizeKind ||
        knownArraySize != other.knownArraySize || name != other.name ||
        typeArguments != other.typeArguments ||
        typeParameterIndex != other.typeParameterIndex) {
        return false;
    }
    if (element == nullptr || other.element == nullptr) {
        return element == other.element;
    }
    return *element == *other.element;
}

SemanticType nullableType(SemanticType element) {
    return aggregate(SemanticTypeKind::Nullable, std::move(element));
}

SemanticType pointerType(SemanticType pointee) {
    return aggregate(SemanticTypeKind::Pointer, std::move(pointee));
}

SemanticType structType(
    std::string name, std::vector<SemanticType> typeArguments) {
    SemanticType type{SemanticTypeKind::Struct};
    type.name = std::move(name);
    type.typeArguments = std::move(typeArguments);
    return type;
}

SemanticType arrayType(SemanticType element, std::uint64_t size) {
    return aggregate(SemanticTypeKind::Array, std::move(element), ArraySizeKind::Known, size);
}

SemanticType inferredArrayType(SemanticType element) {
    return aggregate(SemanticTypeKind::Array, std::move(element), ArraySizeKind::Inferred);
}

SemanticType runtimeArrayType(SemanticType element) {
    return aggregate(SemanticTypeKind::Array, std::move(element), ArraySizeKind::Runtime);
}

SemanticType sliceType(SemanticType element) {
    return aggregate(SemanticTypeKind::Slice, std::move(element));
}

std::string semanticTypeName(const SemanticType& type) {
    switch (type.kind) {
    case SemanticTypeKind::Error: return "<error>";
    case SemanticTypeKind::Unit: return "unit";
    case SemanticTypeKind::Bool: return "bool";
    case SemanticTypeKind::Char: return "char";
    case SemanticTypeKind::String: return "string";
    case SemanticTypeKind::I8: return "i8";
    case SemanticTypeKind::I16: return "i16";
    case SemanticTypeKind::I32: return "i32";
    case SemanticTypeKind::I64: return "i64";
    case SemanticTypeKind::I128: return "i128";
    case SemanticTypeKind::U8: return "u8";
    case SemanticTypeKind::U16: return "u16";
    case SemanticTypeKind::U32: return "u32";
    case SemanticTypeKind::U64: return "u64";
    case SemanticTypeKind::U128: return "u128";
    case SemanticTypeKind::F8: return "f8";
    case SemanticTypeKind::F16: return "f16";
    case SemanticTypeKind::F32: return "f32";
    case SemanticTypeKind::F64: return "f64";
    case SemanticTypeKind::Pointer: return semanticTypeName(*type.element) + "*";
    case SemanticTypeKind::Struct: {
        auto result = type.name;
        if (!type.typeArguments.empty()) {
            result += "<";
            for (std::size_t i = 0; i < type.typeArguments.size(); ++i) {
                if (i > 0) result += ", ";
                result += semanticTypeName(type.typeArguments[i]);
            }
            result += ">";
        }
        return result;
    }
    case SemanticTypeKind::Nullable: return semanticTypeName(*type.element) + "?";
    case SemanticTypeKind::Array:
        if (type.arraySizeKind == ArraySizeKind::Known) {
            return semanticTypeName(*type.element) + "[" +
                std::to_string(type.knownArraySize) + "]";
        }
        if (type.arraySizeKind == ArraySizeKind::Runtime) {
            return semanticTypeName(*type.element) + "[?]";
        }
        return semanticTypeName(*type.element) + "[]";
    case SemanticTypeKind::Slice: return "[]" + semanticTypeName(*type.element);
    case SemanticTypeKind::NullLiteral: return "null";
    case SemanticTypeKind::TypeParameter: return type.name;
    }
    return "<error>";
}

bool isInteger(const SemanticType& type) {
    return type.kind >= SemanticTypeKind::I8 &&
        type.kind <= SemanticTypeKind::U128;
}

bool isFloat(const SemanticType& type) {
    return type.kind >= SemanticTypeKind::F8 &&
        type.kind <= SemanticTypeKind::F64;
}

bool isNumeric(const SemanticType& type) {
    return isInteger(type) || isFloat(type);
}

std::uint32_t numericBitWidth(const SemanticType& type) {
    switch (type.kind) {
    case SemanticTypeKind::I8:
    case SemanticTypeKind::U8:
    case SemanticTypeKind::F8: return 8;
    case SemanticTypeKind::I16:
    case SemanticTypeKind::U16:
    case SemanticTypeKind::F16: return 16;
    case SemanticTypeKind::I32:
    case SemanticTypeKind::U32:
    case SemanticTypeKind::F32: return 32;
    case SemanticTypeKind::I64:
    case SemanticTypeKind::U64:
    case SemanticTypeKind::F64: return 64;
    case SemanticTypeKind::I128:
    case SemanticTypeKind::U128: return 128;
    default: return 0;
    }
}

bool isSignedInteger(const SemanticType& type) {
    return type.kind >= SemanticTypeKind::I8 &&
        type.kind <= SemanticTypeKind::I128;
}

}
