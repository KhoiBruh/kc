module bootstrap.semantic.types;

import bootstrap.source.Source;
import bootstrap.token.Token;
import bootstrap.list.List;
import bootstrap.containers.ByteBuffer;
import bootstrap.containers.StringBuilder;
import bootstrap.lexer.lex;
import bootstrap.ast.AstNode;
import bootstrap.ast.AstKind;
import bootstrap.parser.mod.parse;
import bootstrap.types.TypeValue;
import bootstrap.types.TypeKind;
import bootstrap.types.typeKindFromValue;
import bootstrap.diagnostic.SemanticResult;
import bootstrap.semantic.mod.analyze;
import bootstrap.llvm_text.mod.emitModule;
import bootstrap.token.TokenKind;

fn integerConstant(val semantic: Semantic, root: u64): IntegerConstant {
    var node = semantic.nodes.data[root];
    var negative = false;
    if (node.kind == AstKind.UNARY) {
        if (node.aux != TokenKind.PLUS.value) {
            if (node.aux != TokenKind.MINUS.value) {
                return IntegerConstant(false, false, false, 0);
            }
        }
        negative = node.aux == TokenKind.MINUS.value;
        node = semantic.nodes.data[root - 1];
    }
    if (node.kind != AstKind.LITERAL) return IntegerConstant(false, false, false, 0);
    if (node.aux != TokenKind.INTEGER_LITERAL.value)
        return IntegerConstant(false, false, false, 0);
    var magnitude: u64 = 0;
    var overflow = false;

    for (i in node.start..<node.end) {
        val digit = (semantic.source.data[i] - 48) as u64;
        if (magnitude > 1844674407370955161) {
            overflow = true;
        } else {
            if (magnitude == 1844674407370955161) {
                if (digit > 5) overflow = true;
            }
        }
        if (!overflow) magnitude = magnitude * 10 + digit;
    }

    return IntegerConstant(true, negative, overflow, magnitude);
}

fn floatConstant(val semantic: Semantic, root: u64): IntegerConstant {
    var node = semantic.nodes.data[root];
    var negative = false;
    if (node.kind == AstKind.UNARY) {
        if (node.aux != TokenKind.PLUS.value) {
            if (node.aux != TokenKind.MINUS.value) {
                return IntegerConstant(false, false, false, 0);
            }
        }
        negative = node.aux == TokenKind.MINUS.value;
        node = semantic.nodes.data[root - 1];
    }
    if (node.kind != AstKind.LITERAL) {
        return IntegerConstant(false, false, false, 0);
    }
    if (node.aux != TokenKind.FLOAT_LITERAL.value)
        return IntegerConstant(false, false, false, 0);
    var exponentStart = node.end;
    var decimalDigits: i64 = 0;
    var sawDecimal = false;
    var offset = node.start;

    while (offset < node.end) {
        val byte = semantic.source.data[offset];
        var exponentMarker = byte == 101;
        if (byte == 69) exponentMarker = true;
        if (exponentMarker) {
            exponentStart = offset;
            offset = node.end;
        } else {
            if (byte == 46) sawDecimal = true;
            else {
                if (!sawDecimal) decimalDigits++;
            }
            offset++;
        }
    }

    var exponent: i64 = 0;
    if (exponentStart < node.end) {
        offset = exponentStart + 1;
        var exponentNegative = false;
        var exponentSign = semantic.source.data[offset] == 43;
        if (semantic.source.data[offset] == 45) exponentSign = true;
        if (exponentSign) {
            exponentNegative = semantic.source.data[offset] == 45;
            offset++;
        }
        while (offset < node.end) {
            if (exponent < 1000) {
                exponent = exponent * 10 +
                    (semantic.source.data[offset] - 48) as i64;
            }
            offset++;
        }
        if (exponentNegative) exponent = 0 - exponent;
    }
    val integerDigits = decimalDigits + exponent;
    if (integerDigits <= 0) {
        return IntegerConstant(true, negative, false, 0);
    }
    var digitIndex: i64 = 0;
    var magnitude: u64 = 0;
    var overflow = false;
    offset = node.start;
    while (offset < exponentStart) {
        val byte = semantic.source.data[offset];
        if (byte != 46) {
            if (digitIndex < integerDigits) {
                val digit = (byte - 48) as u64;
                if (magnitude > 1844674407370955161) {
                    overflow = true;
                } else {
                    if (magnitude == 1844674407370955161) {
                        if (digit > 5) overflow = true;
                    }
                }
                if (!overflow) magnitude = magnitude * 10 + digit;
            }
            digitIndex++;
        }
        offset++;
    }
    while (digitIndex < integerDigits) {
        if (magnitude > 1844674407370955161) overflow = true;
        if (!overflow) magnitude = magnitude * 10;
        digitIndex++;
    }
    return IntegerConstant(true, negative, overflow, magnitude);
}

fn integerConstantFits(value: IntegerConstant, target: TypeValue): bool {
    if (value.overflow) return false;
    if (value.negative) {
        if (value.magnitude == 0) return true;
        if (!target.isSigned()) return false;
        if (target.kind == TypeKind.I64) {
            return value.magnitude <= 9223372036854775808;
        }
        return value.magnitude <= 2147483648;
    }
    return when (target.kind) {
        TypeKind.U8 -> value.magnitude <= 255;
        TypeKind.U32 -> value.magnitude <= 4294967295;
        TypeKind.I32 -> value.magnitude <= 2147483647;
        TypeKind.I64 -> value.magnitude <= 9223372036854775807;
        else -> true;
    };
}

fn constraintFromHash(hash: u64): u32 => when (hash) {
    8246182162010039579 -> 1;
    229477778387914 -> 2;
    6953836814478 -> 3;
    229469892001299 -> 4;
    7573017822976354 -> 5;
    210712519067 -> 6;
    else -> 0;
};

fn structTypeParameterRoot(val semantic: Semantic, structureRoot: u64, position: u32): u64 {
    val structure = semantic.nodes.data[structureRoot];
    var root = rootBeforeStructMethods(semantic.nodes, structureRoot);
    val fields = structure.fieldCount();
    for (field in 0..<fields) {
        root = semantic.nodes.data[root].subtreeStart - 1;
    }
    val remaining = structure.structTypeParameterCount();
    for (index in position..<remaining) {
        root = semantic.nodes.data[root].subtreeStart - 1;
    }
    return root;
}

fn structTypeParameterPosition(val semantic: Semantic, structureRoot: u64, name: u64): u32 {
    val count = semantic.nodes.data[structureRoot].structTypeParameterCount();
    for (position in 0..<count) {
        val root = structTypeParameterRoot(semantic, structureRoot, position + 1);
        val parameter = semantic.nodes.data[root];
        if (semantic.hash(semantic.nodes.data[parameter.subtreeStart]) == name) {
            return position;
        }
    }
    return count;
}

fn substituteStructType(
    var semantic: Semantic, structureRoot: u64,
    type: TypeValue, val arguments: List<TypeValue>,
    argumentStart: u64, count: u32
): TypeValue {
    if (type.kind == TypeKind.TYPE_PARAMETER) {
        val position =
            structTypeParameterPosition(semantic, structureRoot, type.name);
        if (position >= count) return invalidType();
        return arguments.data[argumentStart + position as u64];
    }
    if (type.kind == TypeKind.STRUCT) {
        val start = type.pointee % 65536;
        val argCount = type.pointee / 65536;
        if (argCount == 0) return type;
        val newStart = semantic.genericArguments.length;

        for (i in 0..<argCount) {
            val arg = semantic.genericArguments.data[start as u64 + i as u64];
            val substituted = substituteStructType(
                semantic, structureRoot, arg, arguments, argumentStart, count);
            semantic.genericArguments.add(substituted);
        }
        return TypeValue(TypeKind.STRUCT, type.name, newStart as u32 + argCount * 65536);
    }
    if (type.kind == TypeKind.NULLABLE) {
        val inner = substituteStructType(
            semantic, structureRoot,
            TypeValue(typeKindFromValue(type.pointee), type.name, 0), arguments, argumentStart, count);
        return TypeValue(TypeKind.NULLABLE, inner.name, inner.kind.value);
    }
    if (type.kind == TypeKind.POINTER) {
        val inner = substituteStructType(
            semantic, structureRoot,
            TypeValue(typeKindFromValue(type.pointee), type.name, 0), arguments, argumentStart, count);
        return TypeValue(TypeKind.POINTER, inner.name, inner.kind.value);
    }
    if (type.kind == TypeKind.SLICE) {
        val inner = substituteStructType(
            semantic, structureRoot,
            TypeValue(typeKindFromValue(type.pointee), type.name, 0), arguments, argumentStart, count);
        return TypeValue(TypeKind.SLICE, inner.name, inner.kind.value);
    }
    return type;
}

fn findCurrentTypeParameter(
    val semantic: Semantic, name: u64): TypeValue {
    if (semantic.currentFunction < semantic.nodes.length) {
        val function =
            semantic.nodes.data[semantic.currentFunction];
        val count = function.typeParameterCount();
        for (position in 0..<count) {
            val root = functionTypeParameterRoot(
                semantic, semantic.currentFunction, position + 1);
            val parameter = semantic.nodes.data[root];
            val nameNode =
                semantic.nodes.data[parameter.subtreeStart];
            if (semantic.hash(nameNode) == name) {
                var constraint: u32 = 0;
                if (parameter.aux == 1) {
                    constraint = constraintFromHash(
                        semantic.hash(semantic.nodes.data[root - 1]));
                }
                return TypeValue(TypeKind.TYPE_PARAMETER, name, constraint);
            }
        }
    }
    if (semantic.currentStruct < semantic.nodes.length) {
        val structure =
            semantic.nodes.data[semantic.currentStruct];
        val count = structure.structTypeParameterCount();
        for (position in 0..<count) {
            val root = structTypeParameterRoot(
                semantic, semantic.currentStruct, position + 1);
            val parameter = semantic.nodes.data[root];
            val nameNode =
                semantic.nodes.data[parameter.subtreeStart];
            if (semantic.hash(nameNode) == name) {
                var constraint: u32 = 0;
                if (parameter.aux == 1) {
                    constraint = constraintFromHash(
                        semantic.hash(semantic.nodes.data[root - 1]));
                }
                return TypeValue(TypeKind.TYPE_PARAMETER, name, constraint);
            }
        }
    }
    return invalidType();
}

fn typeParameterPosition(
    val semantic: Semantic, functionRoot: u64, name: u64): u32 {
    val count = semantic.nodes.data[functionRoot].typeParameterCount();
    for (position in 0..<count) {
        val root = functionTypeParameterRoot(
            semantic, functionRoot, position + 1);
        val parameter = semantic.nodes.data[root];
        if (semantic.hash(semantic.nodes.data[parameter.subtreeStart]) == name) {
            return position;
        }
    }
    return count;
}

fn substituteGenericType(
    var semantic: Semantic, functionRoot: u64,
    type: TypeValue, arguments: TypeValue*, count: u32): TypeValue {
    if (type.kind == TypeKind.STRUCT) {
        val start = type.pointee % 65536;
        val argumentCount = type.pointee / 65536;
        if (argumentCount == 0) return type;
        val newStart = semantic.genericArguments.length;

        for (i in 0..<argumentCount) {
            val argument = semantic.genericArguments.data[start as u64 + i as u64];
            val substituted = substituteGenericType(
                semantic, functionRoot, argument, arguments, count);
            semantic.genericArguments.add(substituted);
        }
        return TypeValue(TypeKind.STRUCT, type.name, newStart as u32 + argumentCount * 65536);
    }
    if (type.kind == TypeKind.NULLABLE) {
        val inner = substituteGenericType(
            semantic, functionRoot,
            TypeValue(typeKindFromValue(type.pointee), type.name, 0), arguments, count);
        if (inner.kind == TypeKind.INVALID) return inner;
        return TypeValue(TypeKind.NULLABLE, inner.name, inner.kind.value);
    }
    if (type.kind != TypeKind.TYPE_PARAMETER) return type;
    val position =
        typeParameterPosition(semantic, functionRoot, type.name);
    if (position >= count) return invalidType();
    return arguments[position as u64];
}

fn constraintAcceptsType(constraint: u32, type: TypeValue): bool {
    if (constraint == 0) {
        if (type.kind == TypeKind.INVALID) return false;
        if (type.kind == TypeKind.UNIT) return false;
        return true;
    }
    if (type.kind == TypeKind.TYPE_PARAMETER) {
        return type.pointee >= constraint;
    }
    val integer = type.isInteger() || type.kind == TypeKind.INTEGER_LITERAL;
    return when (constraint) {
        1 -> type.kind == TypeKind.BOOL || integer;
        2, 3, 4 -> integer;
        5 -> type.kind == TypeKind.U8 || type.kind == TypeKind.U32 ||
            type.kind == TypeKind.U64 || type.kind == TypeKind.INTEGER_LITERAL;
        else -> false;
    };
}

fn typeFromNode(var semantic: Semantic, root: u64): TypeValue {
    var value = invalidType();
    if (semantic.currentFunction < semantic.nodes.length) {
        if (semantic.currentStruct < semantic.nodes.length) {
        val function = semantic.nodes.data[semantic.currentFunction];
        val structure = semantic.nodes.data[semantic.currentStruct];
        if (function.conversionKind == 1) {
            if (structure.structTypeParameterCount() > 0) {
                if (root == functionParameterRoot(
                        semantic, semantic.currentFunction, 1) - 1) {
                    val count = structure.structTypeParameterCount();
                    val start = semantic.genericArguments.length;
                    for (position in 0..<count) {
                        val parameterRoot = structTypeParameterRoot(
                            semantic, semantic.currentStruct, position + 1);
                        val parameter = semantic.nodes.data[parameterRoot];
                        val nameNode = semantic.nodes.data[parameter.subtreeStart];
                        var constraint: u32 = 0;
                        if (parameter.aux == 1) {
                            constraint = constraintFromHash(semantic.hash(semantic.nodes.data[parameterRoot - 1]));
                        }
                        semantic.genericArguments.add(TypeValue(TypeKind.TYPE_PARAMETER, semantic.hash(nameNode), constraint));
                    }
                    val ownerName = semantic.nodes.data[structure.subtreeStart];
                    value = TypeValue(
                        TypeKind.STRUCT, semantic.hash(ownerName),
                        start as u32 + count * 65536);
                }
            }
        }
        }
    }
    if (value.kind == TypeKind.INVALID) value = inferTypeFromNode(semantic, root);
    var node = semantic.nodes.data[root];
    node.typeKind = value.kind.value;
    node.typeName = value.name;
    node.typePointee = value.pointee;
    semantic.nodes.data[root] = node;
    return value;
}

fn structTypeArgumentRoot(
    val semantic: Semantic, typeRoot: u64, position: u32, count: u32): u64 {
    var root = typeRoot - 1;
    val remaining = count;
    for (index in position..<remaining) {
        root = semantic.nodes.data[root].subtreeStart - 1;
    }
    return root;
}

fn inferTypeFromNode(var semantic: Semantic, root: u64): TypeValue {
    val node = semantic.nodes.data[root];
    if (node.kind == AstKind.NAMED_TYPE) {
        val tokenKind = node.aux % 256;
        val primitive = primitiveType(tokenKind);
        if (primitive.kind != TypeKind.INVALID) return primitive;
        val parameter = findCurrentTypeParameter(
            semantic, semantic.hash(node));
        if (parameter.kind != TypeKind.INVALID) return parameter;
        
        val typeArgumentCount = node.aux / 256;
        if (typeArgumentCount > 0) {
            val start = semantic.genericArguments.length;
            val typeArguments = k_boot_alloc((typeArgumentCount as u64) * sizeof(TypeValue)) as TypeValue*;
            for (index in 0..<typeArgumentCount) {
                val argRoot = structTypeArgumentRoot(semantic, root, index + 1, typeArgumentCount);
                typeArguments[index as u64] = typeFromNode(semantic, argRoot);
            }
            for (index in 0..<typeArgumentCount) {
                semantic.genericArguments.add(typeArguments[index as u64]);
            }
            k_boot_free(typeArguments as unit*);
            return TypeValue(TypeKind.STRUCT, semantic.hash(node), start as u32 + typeArgumentCount * 65536);
        }
        
        val name = semantic.hash(node);
        val enumIndex = declarationFind(semantic.enums, name);
        if (enumIndex != semantic.enums.length) {
            val enumeration = semantic.nodes.data[semantic.enums.data[enumIndex].node];
            return TypeValue(TypeKind.ENUM, name, enumeration.typePointee);
        }
        return TypeValue(TypeKind.STRUCT, name, 0);
    }
    if (node.kind == AstKind.POINTER_TYPE) {
        val inner = typeFromNode(semantic, root - 1);
        if (inner.kind == TypeKind.POINTER) {
            return TypeValue(TypeKind.POINTER, inner.pointee as u64, TypeKind.POINTER.value);
        }
        return TypeValue(TypeKind.POINTER, inner.name, inner.kind.value);
    }
    if (node.kind == AstKind.SLICE_TYPE) {
        val inner = typeFromNode(semantic, root - 1);
        return TypeValue(TypeKind.SLICE, inner.name, inner.kind.value);
    }
    if (node.kind == AstKind.ARRAY_TYPE) {
        var childRoot = root - 1;
        var size: u64 = 0;
        if (node.aux == 1) {
            val constant = integerConstant(semantic, childRoot);
            if (!constant.ok) {
                semantic.fail(4, semantic.nodes.data[childRoot]);
                return invalidType();
            }
            size = constant.magnitude;
            childRoot = semantic.nodes.data[childRoot].subtreeStart - 1;
        }

        return typeFromNode(semantic, childRoot).array(size);
    }
    if (node.kind == AstKind.NULLABLE_TYPE) {
        val inner = typeFromNode(semantic, root - 1);
        return TypeValue(TypeKind.NULLABLE, inner.name, inner.kind.value);
    }
    return invalidType();
}

fn expressionType(var semantic: Semantic, root: u64): TypeValue {
    val value = inferExpressionType(semantic, root);
    var node = semantic.nodes.data[root];
    node.typeKind = value.kind.value;
    node.typeName = value.name;
    node.typePointee = value.pointee;
    semantic.nodes.data[root] = node;
    return value;
}

fn contextualizeLiteralByteSlice(
    var semantic: Semantic, root: u64,
    expected: TypeValue, actual: TypeValue): TypeValue {
    val node = semantic.nodes.data[root];
    if (node.kind != AstKind.LITERAL ||
        node.aux != TokenKind.STRING_LITERAL.value) return actual;
    if (expected.kind != TypeKind.SLICE || expected.pointee != TypeKind.U8.value) return actual;
    var typed = node;
    typed.typeKind = expected.kind.value;
    typed.typeName = expected.name;
    typed.typePointee = expected.pointee;
    semantic.nodes.data[root] = typed;
    return expected;
}

fn typeNeedsOwnership(val semantic: Semantic, value: TypeValue): bool {
    if (value.kind == TypeKind.STR || value.kind == TypeKind.TYPE_PARAMETER || value.kind == TypeKind.ARRAY) return true;
    if (value.kind == TypeKind.NULLABLE) {
        return typeNeedsOwnership(
            semantic, TypeValue(typeKindFromValue(value.pointee), value.name, 0));
    }
    if (value.kind != TypeKind.STRUCT) return false;
    val method = declarationFind(
        semantic.functions, methodHash(value.name, 6385234055));
    if (method == semantic.functions.length) return false;
    val functionRoot = semantic.functions.data[method].node;
    val function = semantic.nodes.data[functionRoot];
    if (function.parameterCount() == 0) return false;
    return semantic.nodes.data[functionParameterRoot(semantic, functionRoot, 1)].mode() == ParameterMode.OWNED;
}
