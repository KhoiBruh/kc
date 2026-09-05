module bootstrap.semantic.expressions;

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

fn nodeIsPrint(val semantic: Semantic, node: AstNode): bool {
    if (node.end - node.start != 5) return false;
    if (semantic.source.data[node.start] != 112) return false;
    if (semantic.source.data[node.start + 1] != 114) return false;
    if (semantic.source.data[node.start + 2] != 105) return false;
    if (semantic.source.data[node.start + 3] != 110) return false;
    return semantic.source.data[node.start + 4] == 116;
}

fn associatedTypeArgumentRoot(
    val semantic: Semantic, memberRoot: u64,
    position: u32, count: u32): u64 {
    var root = memberRoot - 1;
    for (index in position..<count) {
        root = semantic.nodes.data[root].subtreeStart - 1;
    }
    return root;
}

fn associatedObjectRoot(val semantic: Semantic, memberRoot: u64): u64 {
    var root = memberRoot - 1;
    val count = semantic.nodes.data[memberRoot].aux;
    for (index in 0..<count) {
        root = semantic.nodes.data[root].subtreeStart - 1;
    }
    return root;
}

fn inferExpressionType(var semantic: Semantic, root: u64): TypeValue {
    if (!semantic.result.ok) return invalidType();
    val node = semantic.nodes.data[root];
    if (node.kind == AstKind.CALL && node.typeKind != TypeKind.INVALID.value) {
        return TypeValue(
            typeKindFromValue(node.typeKind), node.typeName, node.typePointee);
    }
    if (node.kind == AstKind.IDENTIFIER) {
        val name = semantic.hash(node);
        val local = localFind(semantic.locals, name);
        if (local != semantic.locals.length) {
            if (semantic.locals.data[local].moved) {
                semantic.fail(4, node);
                return semantic.locals.data[local].valueType;
            }
            var resolved = semantic.nodes.data[root];
            resolved.storage = semantic.locals.data[local].storage;
            if (semantic.locals.data[local].autoDrop)
                resolved.ownership = 2;
            semantic.nodes.data[root] = resolved;
            return semantic.locals.data[local].valueType;
        }
        if (declarationFind(semantic.functions, name) !=
                semantic.functions.length) {
            return TypeValue(TypeKind.FUNCTION, name, 0);
        }
        val constant = declarationFind(semantic.constants, name);
        if (constant != semantic.constants.length) {
            val declarationRoot = semantic.constants.data[constant].node;
            var resolved = semantic.nodes.data[root];
            resolved.storage = declarationRoot;
            resolved.aux = 1;
            semantic.nodes.data[root] = resolved;
            val declaration = semantic.nodes.data[declarationRoot];
            return TypeValue(typeKindFromValue(declaration.typeKind), declaration.typeName, declaration.typePointee);
        }
        semantic.fail(2, node);
        return invalidType();
    }
    if (node.kind == AstKind.LITERAL) {
        return when (node.aux) {
            TokenKind.INTEGER_LITERAL.value -> integerLiteralType();
            TokenKind.FLOAT_LITERAL.value -> TypeValue(TypeKind.F64, 0, 0);
            TokenKind.STRING_LITERAL.value -> TypeValue(TypeKind.STR, 0, 0);
            TokenKind.TRUE.value, TokenKind.FALSE.value -> boolType();
            TokenKind.NULL.value -> TypeValue(TypeKind.NULL_LITERAL, 0, 0);
            else -> invalidType();
        };
    }
    if (node.kind == AstKind.UNARY) {
        val operand = expressionType(semantic, root - 1);
        if (node.aux == TokenKind.STAR.value) {
            if (operand.kind != TypeKind.POINTER) {
                semantic.fail(4, node);
                return invalidType();
            }
            if (operand.pointee == TypeKind.POINTER.value) {
                return TypeValue(TypeKind.POINTER, 0, operand.name as u32);
            }
            return TypeValue(typeKindFromValue(operand.pointee), operand.name, 0);
        }
        if (node.aux == TokenKind.AMPERSAND.value) {
            if (operand.kind == TypeKind.POINTER) {
                return TypeValue(TypeKind.POINTER, operand.pointee as u64, TypeKind.POINTER.value);
            }
            return TypeValue(TypeKind.POINTER, operand.name, operand.kind.value);
        }
        if (node.aux == TokenKind.BANG.value) {
            if (operand.kind != TypeKind.BOOL) {
                semantic.fail(4, node);
                return invalidType();
            }
            return TypeValue(TypeKind.BOOL, 0, 0);
        }
        return operand;
    }
    if (node.kind == AstKind.BINARY) {
        val rightRoot = root - 1;
        val leftRoot = semantic.nodes.data[rightRoot].subtreeStart - 1;
        if (node.aux == TokenKind.IN.value) {
            val range = semantic.nodes.data[rightRoot];
            var validRange = range.kind == AstKind.BINARY;
            if (validRange) {
                validRange = range.aux == TokenKind.RANGE.value ||
                    range.aux == TokenKind.RANGE_EXCLUSIVE.value ||
                    range.aux == TokenKind.RANGE_EXCLUSIVE_START.value ||
                    range.aux == TokenKind.RANGE_EXCLUSIVE_BOTH.value;
            }
            if (!validRange) {
                semantic.fail(4, node);
                return boolType();
            }
            val upperRoot = rightRoot - 1;
            val lowerRoot = semantic.nodes.data[upperRoot].subtreeStart - 1;
            val subject = expressionType(semantic, leftRoot);
            var lower = expressionType(semantic, lowerRoot);
            var upper = expressionType(semantic, upperRoot);
            if (lower.kind == TypeKind.INTEGER_LITERAL) {
                lower = subject;
                var lowerNode = semantic.nodes.data[lowerRoot];
                lowerNode.typeKind = subject.kind.value;
                semantic.nodes.data[lowerRoot] = lowerNode;
            }
            if (upper.kind == TypeKind.INTEGER_LITERAL) {
                upper = subject;
                var upperNode = semantic.nodes.data[upperRoot];
                upperNode.typeKind = subject.kind.value;
                semantic.nodes.data[upperRoot] = upperNode;
            }
            if (!subject.isInteger() && !subject.isFloat())
                semantic.fail(4, node);
            if (!subject.accepts(lower, semantic.genericArguments) ||
                !subject.accepts(upper, semantic.genericArguments))
                semantic.fail(4, node);
            var typedRange = range;
            typedRange.typeKind = subject.kind.value;
            typedRange.typeName = subject.name;
            typedRange.typePointee = subject.pointee;
            semantic.nodes.data[rightRoot] = typedRange;
            return boolType();
        }
        val left = expressionType(semantic, leftRoot);
        val right = expressionType(semantic, rightRoot);
        var logical = node.aux == TokenKind.AND_AND.value;
        if (node.aux == TokenKind.OR_OR.value) logical = true;
        if (logical) {
            if (left.kind != TypeKind.BOOL) semantic.fail(4, node);
            else {
                if (right.kind != TypeKind.BOOL) semantic.fail(4, node);
            }
            return boolType();
        }
        val comparison = when (node.aux) {
            TokenKind.LESS.value,
            TokenKind.GREATER.value,
            TokenKind.EQUAL_EQUAL.value,
            TokenKind.BANG_EQUAL.value,
            TokenKind.LESS_EQUAL.value,
            TokenKind.GREATER_EQUAL.value -> true;
            else -> false;
        };
        if (comparison) {
            if (!left.accepts(right, semantic.genericArguments)) {
                if (!right.accepts(left, semantic.genericArguments)) {
                    semantic.fail(4, node);
                }
            }
            return boolType();
        }
        if (left.accepts(right, semantic.genericArguments)) return left;
        if (right.accepts(left, semantic.genericArguments)) return right;
        semantic.fail(4, node);
        return invalidType();
    }
    if (node.kind == AstKind.ASSIGNMENT) {
        val rightRoot = root - 1;
        val leftRoot = semantic.nodes.data[rightRoot].subtreeStart - 1;
        val target = semantic.nodes.data[leftRoot];
        var targetLocal = semantic.locals.length;
        if (target.kind == AstKind.IDENTIFIER) {
            targetLocal = localFind(semantic.locals, semantic.hash(target));
            if (targetLocal == semantic.locals.length) {
                semantic.fail(2, target);
                return invalidType();
            }
            if (!semantic.locals.data[targetLocal].mutable) {
                semantic.fail(7, target);
                return invalidType();
            }
        }
        var left = invalidType();
        if (targetLocal != semantic.locals.length) {
            left = semantic.locals.data[targetLocal].valueType;
            var resolvedTarget = target;
            resolvedTarget.storage = semantic.locals.data[targetLocal].storage;
            resolvedTarget.typeKind = left.kind.value;
            resolvedTarget.typeName = left.name;
            resolvedTarget.typePointee = left.pointee;
            if (semantic.locals.data[targetLocal].autoDrop)
                resolvedTarget.ownership = 2;
            semantic.nodes.data[leftRoot] = resolvedTarget;
            if (node.aux != TokenKind.EQUAL.value &&
                semantic.locals.data[targetLocal].moved) {
                semantic.fail(4, target);
                return left;
            }
        } else {
            left = expressionType(semantic, leftRoot);
        }
        var right = expressionType(semantic, rightRoot);
        right = contextualizeLiteralByteSlice(
            semantic, rightRoot, left, right);
        if (!left.accepts(right, semantic.genericArguments)) {
            semantic.fail(4, node);
        } else if (node.aux == TokenKind.EQUAL.value) {
            markExpressionMoved(semantic, rightRoot);
            if (targetLocal != semantic.locals.length) {
                var reassigned = semantic.locals.data[targetLocal];
                reassigned.moved = false;
                semantic.locals.data[targetLocal] = reassigned;
            }
        }
        return left;
    }
    if (node.kind == AstKind.CAST) {
        val typeRoot = root - 1;
        val valueRoot = semantic.nodes.data[typeRoot].subtreeStart - 1;
        var source = expressionType(semantic, valueRoot);
        val target = typeFromNode(semantic, typeRoot);
        if (source.kind == TypeKind.INTEGER_LITERAL) {
            source = TypeValue(TypeKind.I32, 0, 0);
            var valueNode = semantic.nodes.data[valueRoot];
            valueNode.typeKind = source.kind.value;
            semantic.nodes.data[valueRoot] = valueNode;
        }
        var pointerCast = false;
        if (source.kind == TypeKind.POINTER) {
            if (target.kind == TypeKind.POINTER) pointerCast = true;
        }
        var integerCast = false;
        if (source.isInteger()) {
            if (target.isInteger()) integerCast = true;
        }
        if (integerCast) {
            val constant = integerConstant(semantic, valueRoot);
            if (constant.ok) {
                if (!integerConstantFits(constant, target)) {
                    semantic.fail(4, node);
                }
            }
            var castNode = semantic.nodes.data[root];
            castNode.conversionKind = 3;
            if (source.requiresRangeCheck(target)) {
                castNode.conversionKind = 4;
            }
            semantic.nodes.data[root] = castNode;
        } else {
            var floatCast = false;
            if (source.isFloat()) {
                if (target.isFloat()) floatCast = true;
            }
            if (source.isInteger()) {
                if (target.isFloat()) floatCast = true;
            }
            var floatToInteger = false;
            if (source.isFloat()) {
                if (target.isInteger()) floatToInteger = true;
            }
            if (floatToInteger) {
                floatCast = true;
                val constant = floatConstant(semantic, valueRoot);
                if (constant.ok) {
                    if (!integerConstantFits(constant, target)) {
                        semantic.fail(4, node);
                    }
                }
            }
            if (floatCast) {
                var castNode = semantic.nodes.data[root];
                castNode.conversionKind = 5;
                if (floatToInteger) {
                    castNode.conversionKind = 6;
                }
                semantic.nodes.data[root] = castNode;
            } else {
                if (!pointerCast) semantic.fail(4, node);
            }
        }
        return target;
    }
    if (node.kind == AstKind.CALL) {
        var argumentCount = node.callArgumentCount();
        val callExplicitTypeCount = node.callTypeArgumentCount();
        val argumentRoots =
            k_boot_alloc(
                ((argumentCount + 1) as u64) * sizeof(u64)) as u64*;
        var cursor = root - 1;
        for (argument in argumentCount>..0) {
            cursor = semantic.nodes.data[cursor].subtreeStart - 1;
        }
        var calleeRoot = cursor;
        for (explicit in 0..<callExplicitTypeCount) {
            calleeRoot = semantic.nodes.data[calleeRoot].subtreeStart - 1;
        }
        val callee = semantic.nodes.data[calleeRoot];
        var explicitTypeCount = callExplicitTypeCount;
        if (callee.kind == AstKind.MEMBER) explicitTypeCount = callee.aux;
        val explicitTypeRoots =
            k_boot_alloc(
                (explicitTypeCount as u64) * sizeof(u64)) as u64*;
        cursor = root - 1;
        for (argument in argumentCount>..0) {
            argumentRoots[argument as u64] = cursor;
            cursor = semantic.nodes.data[cursor].subtreeStart - 1;
        }
        for (explicit in callExplicitTypeCount>..0) {
            explicitTypeRoots[explicit as u64] = cursor;
            cursor = semantic.nodes.data[cursor].subtreeStart - 1;
        }
        var functionName: u64 = 0;
        var associated = false;
        if (callee.kind == AstKind.IDENTIFIER) {
            functionName = semantic.hash(callee);
        } else {
            if (callee.kind == AstKind.MEMBER) {
                val objectRoot = associatedObjectRoot(semantic, cursor);
                val objectNode = semantic.nodes.data[objectRoot];
                if (objectNode.kind == AstKind.IDENTIFIER) {
                    val structureIndex = declarationFind(
                        semantic.structs, semantic.hash(objectNode));
                    if (structureIndex != semantic.structs.length) {
                        val candidateName = methodHash(
                            semantic.structs.data[structureIndex].name,
                            semantic.hash(callee));
                        val candidateIndex = declarationFind(
                            semantic.functions, candidateName);
                        if (candidateIndex != semantic.functions.length) {
                            val candidate = semantic.nodes.data[
                                semantic.functions.data[candidateIndex].node];
                            if (candidate.conversionKind == 2) {
                                associated = true;
                                functionName = candidateName;
                                for (explicit in 0..<callee.aux) {
                                    explicitTypeRoots[explicit as u64] =
                                        associatedTypeArgumentRoot(
                                             semantic, cursor,
                                            explicit + 1, callee.aux);
                                }
                            }
                        }
                    }
                }
                if (!associated && callExplicitTypeCount == 0 && callee.aux == 0) {
                    val object = expressionType(semantic, objectRoot);
                    if (object.kind == TypeKind.STRUCT) {
                        for (argument in argumentCount>..0) {
                            argumentRoots[argument as u64 + 1] =
                                argumentRoots[argument as u64];
                        }
                        argumentRoots[0] = objectRoot;
                        argumentCount++;
                        functionName = methodHash(
                            object.name, semantic.hash(callee));
                    }
                }
            }
        }
        if (functionName == 0) {
            semantic.fail(2, callee);
            k_boot_free(explicitTypeRoots as unit*);
            k_boot_free(argumentRoots as unit*);
            return invalidType();
        }
        val functionIndex = declarationFind(semantic.functions, functionName);
        if (functionIndex == semantic.functions.length) {
            if (callee.kind == AstKind.IDENTIFIER &&
                functionName == 210727929557 &&
                localFind(semantic.locals, functionName) == semantic.locals.length) {
                if (argumentCount != 2) {
                    semantic.fail(3, callee);
                    k_boot_free(explicitTypeRoots as unit*);
                    k_boot_free(argumentRoots as unit*);
                    return invalidType();
                }
                val pointer = expressionType(semantic, argumentRoots[0]);
                val length = expressionType(semantic, argumentRoots[1]);
                if (pointer.kind != TypeKind.POINTER || pointer.pointee == TypeKind.UNIT.value) {
                    semantic.fail(4, semantic.nodes.data[argumentRoots[0]]);
                    k_boot_free(explicitTypeRoots as unit*);
                    k_boot_free(argumentRoots as unit*);
                    return invalidType();
                }
                if (!TypeValue(TypeKind.U64, 0, 0).accepts(
                        length, semantic.genericArguments)) {
                    semantic.fail(4, semantic.nodes.data[argumentRoots[1]]);
                    k_boot_free(explicitTypeRoots as unit*);
                    k_boot_free(argumentRoots as unit*);
                    return invalidType();
                }
                k_boot_free(explicitTypeRoots as unit*);
                k_boot_free(argumentRoots as unit*);
                return TypeValue(TypeKind.SLICE, pointer.name, pointer.pointee);
            }
            if (nodeIsPrint(semantic, callee)) {
                if (argumentCount != 1) {
                    semantic.fail(3, callee);
                    k_boot_free(explicitTypeRoots as unit*);
                    k_boot_free(argumentRoots as unit*);
                    return invalidType();
                }
                expressionType(semantic, argumentRoots[0]);
                k_boot_free(explicitTypeRoots as unit*);
                k_boot_free(argumentRoots as unit*);
                return unitType();
            }
            val structureIndex = declarationFind(semantic.structs, semantic.hash(callee));
            if (structureIndex == semantic.structs.length) {
                semantic.fail(2, callee);
                k_boot_free(explicitTypeRoots as unit*);
                k_boot_free(argumentRoots as unit*);
                return invalidType();
            }
            val structureRoot =
                semantic.structs.data[structureIndex].node;
            val structure = semantic.nodes.data[structureRoot];
            val fieldCount = structure.fieldCount();
            val typeCount = structure.structTypeParameterCount();
            if (fieldCount != argumentCount) {
                semantic.fail(3, callee);
                k_boot_free(explicitTypeRoots as unit*);
                k_boot_free(argumentRoots as unit*);
                return invalidType();
            }
            if (explicitTypeCount > 0) {
                if (explicitTypeCount != typeCount) {
                    semantic.fail(3, callee);
                    k_boot_free(explicitTypeRoots as unit*);
                    k_boot_free(argumentRoots as unit*);
                    return invalidType();
                }
            }
            val typeArguments =
                k_boot_alloc(
                    (typeCount as u64) * sizeof(TypeValue)) as TypeValue*;
            for (explicit in 0..<typeCount) {
                typeArguments[explicit as u64] = invalidType();
            }
            for (explicit in 0..<explicitTypeCount) {
                typeArguments[explicit as u64] =
                    typeFromNode(
                        semantic,
                        explicitTypeRoots[explicit as u64]);
            }
            for (argument in 0..<argumentCount) {
                var actual = expressionType(
                    semantic, argumentRoots[argument as u64]);
                val fieldRoot = fieldRootAt(semantic.nodes, structureRoot, argument);
                val savedStruct = semantic.currentStruct;
                semantic.currentStruct = structureRoot;
                val pattern = typeFromNode(semantic, fieldRoot - 1);
                semantic.currentStruct = savedStruct;
                if (pattern.kind == TypeKind.TYPE_PARAMETER) {
                    val position = structTypeParameterPosition(
                        semantic, structureRoot, pattern.name);
                    if (explicitTypeCount == 0) {
                        var inferredActual = actual;
                        if (inferredActual.kind == TypeKind.INTEGER_LITERAL) {
                            inferredActual = TypeValue(TypeKind.I32, 0, 0);
                        }
                        if (typeArguments[position as u64].kind == TypeKind.INVALID) {
                            typeArguments[position as u64] = inferredActual;
                        } else {
                            if (
                                !typeArguments[position as u64].equals(
                                    inferredActual, semantic.genericArguments
                                )
                            ) {
                                semantic.fail(
                                    4,
                                    semantic.nodes.data[
                                        argumentRoots[argument as u64]]);
                            }
                        }
                    }
                } else {
                    if (actual.kind == TypeKind.INTEGER_LITERAL) {
                        if (pattern.isInteger()) actual = pattern;
                    }
                }
                val expected = substituteStructType(
                    semantic, structureRoot, pattern,
                    List<TypeValue>(
                        typeArguments, typeCount as u64, typeCount as u64,
                        sizeof(TypeValue)),
                    0, typeCount);
                actual = contextualizeLiteralByteSlice(
                    semantic, argumentRoots[argument as u64], expected, actual);
                if (!expected.accepts(actual, semantic.genericArguments)) {
                    semantic.fail(
                        4,
                        semantic.nodes.data[
                            argumentRoots[argument as u64]]);
                }
                markExpressionMoved(
                    semantic, argumentRoots[argument as u64]);
            }
            for (explicit in 0..<typeCount) {
                val parameterRoot = structTypeParameterRoot(
                    semantic, structureRoot, explicit + 1);
                val parameter = semantic.nodes.data[parameterRoot];
                var constraint: u32 = 0;
                if (parameter.aux == 1) {
                    constraint = constraintFromHash(
                        semantic.hash(semantic.nodes.data[parameterRoot - 1]));
                }

                if (
                    !constraintAcceptsType(
                        constraint,
                        typeArguments[explicit as u64]
                    )
                ) semantic.fail(4, callee);

            }
            var start: u32 = 0;
            if (typeCount > 0) {
                start = semantic.genericArguments.length as u32;
                var callNode = semantic.nodes.data[root];
                callNode.genericArgumentStart = start as u64;
                callNode.genericArgumentCount = typeCount;
                for (typeIndex in 0..<typeCount) {
                    semantic.genericArguments.add(typeArguments[typeIndex as u64]);
                }
                semantic.nodes.data[root] = callNode;
            }
            var callResult = semantic.nodes.data[root];
            callResult.typeKind = TypeKind.STRUCT.value;
            callResult.typeName = semantic.structs.data[structureIndex].name;
            callResult.typePointee = start + typeCount * 65536;
            semantic.nodes.data[root] = callResult;
            k_boot_free(typeArguments as unit*);
            k_boot_free(explicitTypeRoots as unit*);
            k_boot_free(argumentRoots as unit*);
            return TypeValue(
                TypeKind.STRUCT, semantic.structs.data[structureIndex].name, start + typeCount * 65536);
        }
        val functionRoot = semantic.functions.data[functionIndex].node;
        val function = semantic.nodes.data[functionRoot];
        var resolvedCall = semantic.nodes.data[root];
        resolvedCall.storage = functionRoot;
        semantic.nodes.data[root] = resolvedCall;
        if (function.conversionKind == 1) {
            val receiverParameter = semantic.nodes.data[
                functionParameterRoot(semantic, functionRoot, 1)];
            if (receiverParameter.mode() == ParameterMode.MUTABLE_BORROW) {
                val receiverNode = semantic.nodes.data[argumentRoots[0]];
                if (receiverNode.kind == AstKind.IDENTIFIER) {
                    val receiverLocal =
                        localFind(semantic.locals, semantic.hash(receiverNode));
                    if (receiverLocal == semantic.locals.length) {
                        semantic.fail(7, receiverNode);
                    } else {
                        if (!semantic.locals.data[receiverLocal].mutable)
                            semantic.fail(7, receiverNode);
                    }
                }
            }
        }
        if (function.parameterCount() != argumentCount) {
            semantic.fail(3, callee);
            k_boot_free(explicitTypeRoots as unit*);
            k_boot_free(argumentRoots as unit*);
            return invalidType();
        }
        val methodOwner = methodOwnerStructRoot(semantic, functionRoot);
        val typeCount = if (methodOwner != semantic.nodes.length)
                semantic.nodes.data[methodOwner].structTypeParameterCount()
            else function.typeParameterCount();
        if (associated) {
            if (explicitTypeCount != typeCount) {
                semantic.fail(3, callee);
                k_boot_free(explicitTypeRoots as unit*);
                k_boot_free(argumentRoots as unit*);
                return invalidType();
            }
        } else if (explicitTypeCount > 0) {
            if (explicitTypeCount != typeCount) {
                semantic.fail(3, callee);
                k_boot_free(explicitTypeRoots as unit*);
                k_boot_free(argumentRoots as unit*);
                return invalidType();
            }
        }
        val typeArguments =
            k_boot_alloc(
                (typeCount as u64) * sizeof(TypeValue)) as TypeValue*;
        for (explicit in 0..<typeCount) {
            typeArguments[explicit as u64] = invalidType();
        }
        var receiver = invalidType();
        if (methodOwner != semantic.nodes.length) {
            if (associated) {
                for (explicit in 0..<explicitTypeCount) {
                    typeArguments[explicit as u64] =
                        typeFromNode(
                            semantic,
                            explicitTypeRoots[explicit as u64]);
                }
            } else {
                receiver = expressionType(semantic, argumentRoots[0]);
                val start = receiver.pointee % 65536;
                val count = receiver.pointee / 65536;
                if (receiver.kind != TypeKind.STRUCT || count != typeCount) {
                    semantic.fail(4, callee);
                } else {
                    for (position in 0..<typeCount) {
                        typeArguments[position as u64] = semantic.genericArguments.data[
                            start as u64 + position as u64];
                    }
                }
            }
        } else {
            for (explicit in 0..<explicitTypeCount) {
                typeArguments[explicit as u64] =
                    typeFromNode(
                        semantic,
                        explicitTypeRoots[explicit as u64]);
            }
        }
        for (argument in 0..<argumentCount) {
            var actual = invalidType();
            if (argument == 0 && !associated &&
                    methodOwner != semantic.nodes.length) {
                actual = receiver;
            } else {
                actual = expressionType(
                    semantic, argumentRoots[argument as u64]);
            }
            val parameterRoot =
                functionParameterRoot(
                    semantic, functionRoot, argument + 1);
            val savedFunction = semantic.currentFunction;
            val savedStruct = semantic.currentStruct;
            semantic.currentFunction = functionRoot;
            if (methodOwner != semantic.nodes.length)
                semantic.currentStruct = methodOwner;
            val pattern = typeFromNode(semantic, parameterRoot - 1);
            semantic.currentFunction = savedFunction;
            semantic.currentStruct = savedStruct;
            if (pattern.kind == TypeKind.TYPE_PARAMETER) {
                var position = typeParameterPosition(
                    semantic, functionRoot, pattern.name);
                if (methodOwner != semantic.nodes.length) {
                    position = structTypeParameterPosition(
                        semantic, methodOwner, pattern.name);
                }
                if (explicitTypeCount == 0 &&
                    methodOwner == semantic.nodes.length) {
                    var inferredActual = actual;
                    if (inferredActual.kind == TypeKind.INTEGER_LITERAL) {
                        inferredActual = TypeValue(TypeKind.I32, 0, 0);
                    }
                    if (typeArguments[position as u64].kind == TypeKind.INVALID) {
                        typeArguments[position as u64] = inferredActual;
                    } else {
                        if (
                            !typeArguments[position as u64].equals(
                                inferredActual, semantic.genericArguments
                            )
                        ) {
                            semantic.fail(
                                4,
                                semantic.nodes.data[
                                    argumentRoots[argument as u64]]);
                        }
                    }
                }
            }
            var expected = substituteGenericType(
                semantic, functionRoot, pattern,
                typeArguments, typeCount);
            if (methodOwner != semantic.nodes.length) {
                expected = substituteStructType(
                    semantic, methodOwner, pattern,
                    List<TypeValue>(
                        typeArguments, typeCount as u64, typeCount as u64,
                        sizeof(TypeValue)),
                    0, typeCount);
            }
            actual = contextualizeLiteralByteSlice(
                semantic, argumentRoots[argument as u64], expected, actual);
            if (!expected.accepts(actual, semantic.genericArguments)) {
                semantic.fail(
                    4,
                    semantic.nodes.data[
                        argumentRoots[argument as u64]]);
            }
            if (semantic.nodes.data[parameterRoot].mode() ==
                    ParameterMode.OWNED) {
                markExpressionMoved(
                    semantic, argumentRoots[argument as u64]);
            }
        }
        for (explicit in 0..<typeCount) {
            var parameterRoot = functionTypeParameterRoot(
                semantic, functionRoot, explicit + 1);
            if (methodOwner != semantic.nodes.length) {
                parameterRoot = structTypeParameterRoot(
                    semantic, methodOwner, explicit + 1);
            }
            val parameter = semantic.nodes.data[parameterRoot];
            var constraint: u32 = 0;
            if (parameter.aux == 1) {
                constraint = constraintFromHash(
                    semantic.hash(semantic.nodes.data[parameterRoot - 1]));
            }

            if (
                !constraintAcceptsType(
                    constraint,
                    typeArguments[explicit as u64]
                )
            ) semantic.fail(4, callee);

        }
        val savedFunction = semantic.currentFunction;
        val savedStruct = semantic.currentStruct;
        semantic.currentFunction = functionRoot;
        if (methodOwner != semantic.nodes.length)
            semantic.currentStruct = methodOwner;
        val returnPattern = functionReturnTypeValue(semantic, functionRoot);
        semantic.currentFunction = savedFunction;
        semantic.currentStruct = savedStruct;
        var returnType = substituteGenericType(
            semantic, functionRoot, returnPattern,
            typeArguments, typeCount);
        if (methodOwner != semantic.nodes.length) {
            returnType = substituteStructType(
                semantic, methodOwner, returnPattern,
                List<TypeValue>(
                    typeArguments, typeCount as u64, typeCount as u64,
                    sizeof(TypeValue)),
                0, typeCount);
        }
        if (typeCount > 0) {
            var callNode = semantic.nodes.data[root];
            callNode.genericArgumentStart =
                semantic.genericArguments.length;
            callNode.genericArgumentCount = typeCount;
            for (typeIndex in 0..<typeCount) {
                semantic.genericArguments.add(typeArguments[typeIndex as u64]);
            }
            semantic.nodes.data[root] = callNode;
        }
        k_boot_free(typeArguments as unit*);
        k_boot_free(explicitTypeRoots as unit*);
        k_boot_free(argumentRoots as unit*);
        return returnType;
    }
    if (node.kind == AstKind.MEMBER) {
        val objectRoot = root - 1;
        val objectNode = semantic.nodes.data[objectRoot];
        if (objectNode.kind == AstKind.IDENTIFIER) {
            val enumIndex = declarationFind(semantic.enums, semantic.hash(objectNode));
            if (enumIndex != semantic.enums.length) {
                val enumRoot = semantic.enums.data[enumIndex].node;
                val enumeration = semantic.nodes.data[enumRoot];
                val wanted = semantic.hash(node);
                for (position in 0..<enumeration.aux) {
                    val variant = semantic.nodes.data[
                        enumVariantStart(enumeration) + position as u64];
                    if (semantic.hash(variant) == wanted) {
                        var resolvedObject = objectNode;
                        resolvedObject.typeKind = TypeKind.ENUM.value;
                        resolvedObject.typeName = semantic.enums.data[enumIndex].name;
                        resolvedObject.typePointee = enumeration.typePointee;
                        semantic.nodes.data[objectRoot] = resolvedObject;
                        var resolved = node;
                        resolved.storage = variant.storage;
                        resolved.conversionKind = position;
                        resolved.typeKind = TypeKind.ENUM.value;
                        resolved.typeName = semantic.enums.data[enumIndex].name;
                        resolved.typePointee = enumeration.typePointee;
                        semantic.nodes.data[root] = resolved;
                        return TypeValue(
                            TypeKind.ENUM, resolved.typeName,
                            enumeration.typePointee);
                    }
                }
                semantic.fail(2, node);
                return invalidType();
            }
        }
        val object = expressionType(semantic, objectRoot);
        if (object.kind == TypeKind.ENUM) {
            if (semantic.hash(node) == 210731095874) {
                var resolved = node;
                resolved.typeKind = object.pointee;
                semantic.nodes.data[root] = resolved;
                return TypeValue(typeKindFromValue(object.pointee), 0, 0);
            }
            semantic.fail(8, node);
            return invalidType();
        }
        if (object.kind == TypeKind.STR) {
            if (semantic.hash(node) == 210708248140) {
                return TypeValue(TypeKind.SLICE, 0, TypeKind.U8.value);
            }
            semantic.fail(8, node);
            return invalidType();
        }
        if (object.kind != TypeKind.STRUCT) {
            semantic.fail(8, node);
            return invalidType();
        }
        val structureIndex =
            declarationFind(semantic.structs, object.name);
        if (structureIndex == semantic.structs.length) {
            semantic.fail(8, node);
            return invalidType();
        }
        val structureRoot = semantic.structs.data[structureIndex].node;
        val structure = semantic.nodes.data[structureRoot];
        val wanted = semantic.hash(node);
        var cursor = rootBeforeStructMethods(semantic.nodes, structureRoot);
        val remaining = structure.fieldCount();
        for (fieldIndex in 0..<remaining) {
            val field = semantic.nodes.data[cursor];
            val fieldName = semantic.nodes.data[field.subtreeStart];
            if (semantic.hash(fieldName) == wanted) {
                val savedStruct = semantic.currentStruct;
                semantic.currentStruct = structureRoot;
                val fieldType = typeFromNode(semantic, cursor - 1);
                semantic.currentStruct = savedStruct;
                val start = object.pointee % 65536;
                val count = object.pointee / 65536;
                if (count > 0) {
                    return substituteStructType(
                        semantic, structureRoot, fieldType,
                        semantic.genericArguments, start as u64, count);
                }
                return fieldType;
            }
            cursor = field.subtreeStart - 1;
        }
        semantic.fail(8, node);
        return invalidType();
    }
    if (node.kind == AstKind.INDEX) {
        val indexRoot = root - 1;
        val objectRoot = semantic.nodes.data[indexRoot].subtreeStart - 1;
        val object = expressionType(semantic, objectRoot);
        expressionType(semantic, indexRoot);
        if (object.kind == TypeKind.ARRAY) {
            return object.arrayElement();
        }
        if (object.kind == TypeKind.SLICE) {
            return TypeValue(typeKindFromValue(object.pointee), object.name, 0);
        }
        if (object.kind != TypeKind.POINTER) {
            semantic.fail(8, node);
            return invalidType();
        }
        if (object.pointee == TypeKind.POINTER.value) {
            return TypeValue(TypeKind.POINTER, 0, object.name as u32);
        }
        return TypeValue(typeKindFromValue(object.pointee), object.name, 0);
    }
    if (node.kind == AstKind.POSTFIX) {
        val operand = expressionType(semantic, root - 1);
        if (node.aux == TokenKind.PLUS_PLUS.value ||
            node.aux == TokenKind.MINUS_MINUS.value) {
            if (semantic.mutationRoot != root) semantic.fail(4, node);
            if (!operand.isFloat() && !operand.isInteger())
                semantic.fail(4, node);
            val target = semantic.nodes.data[root - 1];
            if (target.kind == AstKind.IDENTIFIER) {
                val local = localFind(semantic.locals, semantic.hash(target));
                if (local == semantic.locals.length) semantic.fail(2, target);
                else {
                    if (!semantic.locals.data[local].mutable)
                        semantic.fail(7, target);
                }
            }
            return operand;
        }
        if (operand.kind != TypeKind.NULLABLE) {
            semantic.fail(4, node);
            return invalidType();
        }
        return TypeValue(typeKindFromValue(operand.pointee), operand.name, 0);
    }
    if (node.kind == AstKind.IF_EXPRESSION) {
        val thenCount = node.aux % 65536;
        val elseCount = node.aux / 65536;
        val elseValueRoot = root - 1;
        val elseRoots =
            k_boot_alloc((elseCount as u64) * sizeof(u64)) as u64*;
        var childRoot = semantic.nodes.data[elseValueRoot].subtreeStart - 1;
        for (index in elseCount>..0) {
            elseRoots[index as u64] = childRoot;
            childRoot = semantic.nodes.data[childRoot].subtreeStart - 1;
        }
        val thenValueRoot = childRoot;
        val thenRoots =
            k_boot_alloc((thenCount as u64) * sizeof(u64)) as u64*;
        childRoot = semantic.nodes.data[thenValueRoot].subtreeStart - 1;
        for (index in thenCount>..0) {
            thenRoots[index as u64] = childRoot;
            childRoot = semantic.nodes.data[childRoot].subtreeStart - 1;
        }
        val condition = expressionType(semantic, childRoot);
        if (condition.kind != TypeKind.BOOL) {
            semantic.fail(6, semantic.nodes.data[childRoot]);
        }
        val savedLocals = semantic.locals.length;
        val savedScopeStart = semantic.scopeStart;
        val ownershipBefore = captureOwnership(semantic, savedLocals);
        semantic.scopeStart = savedLocals;
        for (index in 0..<thenCount) {
            checkStatement(semantic, thenRoots[index as u64]);
        }
        val thenType = expressionType(semantic, thenValueRoot);
        semantic.locals.setLength(savedLocals);
        val thenOwnership = captureOwnership(semantic, savedLocals);
        restoreOwnership(semantic, ownershipBefore, savedLocals);
        semantic.scopeStart = savedLocals;
        for (index in 0..<elseCount) {
            checkStatement(semantic, elseRoots[index as u64]);
        }
        val elseType = expressionType(semantic, elseValueRoot);
        semantic.locals.setLength(savedLocals);
        val elseOwnership = captureOwnership(semantic, savedLocals);
        mergeOwnership(
            semantic, thenOwnership, elseOwnership, savedLocals);
        semantic.scopeStart = savedScopeStart;
        k_boot_free(elseOwnership as unit*);
        k_boot_free(thenOwnership as unit*);
        k_boot_free(ownershipBefore as unit*);
        k_boot_free(thenRoots as unit*);
        k_boot_free(elseRoots as unit*);
        if (!thenType.accepts(elseType, semantic.genericArguments)) {
            semantic.fail(4, semantic.nodes.data[elseValueRoot]);
        }
        var resolved = semantic.nodes.data[root];
        resolved.typeKind = thenType.kind.value;
        resolved.typeName = thenType.name;
        resolved.typePointee = thenType.pointee;
        semantic.nodes.data[root] = resolved;
        return thenType;
    }
    if (node.kind == AstKind.WHEN_EXPRESSION) {
        val branchCount = node.whenBranchCount();
        val hasSubject = if (node.whenHasSubject()) 1 else 0;
        val roots = k_boot_alloc((branchCount as u64) * sizeof(u64)) as u64*;
        var branchRoot = root - 1;
        for (index in branchCount>..0) {
            roots[index as u64] = branchRoot;
            branchRoot = semantic.nodes.data[branchRoot].subtreeStart - 1;
        }
        var subject = invalidType();
        if (hasSubject == 1) {
            subject = expressionType(semantic, branchRoot);
            if (subject.kind == TypeKind.INTEGER_LITERAL) {
                subject = TypeValue(TypeKind.I32, 0, 0);
                var subjectNode = semantic.nodes.data[branchRoot];
                subjectNode.typeKind = TypeKind.I32.value;
                semantic.nodes.data[branchRoot] = subjectNode;
            }
        }
        var result = invalidType();
        var hasElse = false;
        val ownershipCount = semantic.locals.length;
        val ownershipBefore = captureOwnership(semantic, ownershipCount);
        val ownershipMerged = k_boot_alloc(ownershipCount) as u8*;
        for (ownershipIndex in 0..<ownershipCount) {
            ownershipMerged[ownershipIndex] = 0 as u8;
        }
        for (index in 0..<branchCount) {
            restoreOwnership(semantic, ownershipBefore, ownershipCount);
            val branch = semantic.nodes.data[roots[index as u64]];
            if (branch.whenBranchIsElse()) hasElse = true;
            val valueRoot = roots[index as u64] - 1;
            val statementCount = (branch.aux % 65536) / 2;
            val statementRoots =
                k_boot_alloc((statementCount as u64) * sizeof(u64)) as u64*;
            var beforeValue = semantic.nodes.data[valueRoot].subtreeStart - 1;
            for (statementIndex in statementCount>..0) {
                statementRoots[statementIndex as u64] = beforeValue;
                beforeValue = semantic.nodes.data[beforeValue].subtreeStart - 1;
            }
            if (!branch.whenBranchIsElse()) {
              val patternCount = branch.whenBranchPatternCount();
              for (patternIndex in 0..<patternCount) {
                val conditionRoot = whenPatternRoot(
                    semantic, roots[index as u64], true, patternIndex);
                val condition = expressionType(semantic, conditionRoot);
                if (hasSubject == 1) {
                    if (!subject.accepts(condition, semantic.genericArguments)) {
                        semantic.fail(4, semantic.nodes.data[conditionRoot]);
                    } else {
                        var conditionNode = semantic.nodes.data[conditionRoot];
                        conditionNode.typeKind = subject.kind.value;
                        conditionNode.typeName = subject.name;
                        conditionNode.typePointee = subject.pointee;
                        semantic.nodes.data[conditionRoot] = conditionNode;
                    }
                } else {
                    if (condition.kind != TypeKind.BOOL) {
                        semantic.fail(6, semantic.nodes.data[conditionRoot]);
                    }
                }
              }
            }
            val savedLocals = semantic.locals.length;
            val savedScopeStart = semantic.scopeStart;
            semantic.scopeStart = savedLocals;
            for (statementIndex in 0..<statementCount) {
                checkStatement(semantic, statementRoots[statementIndex as u64]);
            }
            var value = expressionType(semantic, valueRoot);
            semantic.locals.setLength(savedLocals);
            semantic.scopeStart = savedScopeStart;
            includeCurrentOwnership(
                semantic, ownershipMerged, ownershipCount);
            k_boot_free(statementRoots as unit*);
            if (result.kind == TypeKind.INVALID) {
                result = value;
            } else {
                if (!result.accepts(value, semantic.genericArguments)) {
                    semantic.fail(4, semantic.nodes.data[valueRoot]);
                } else {
                    var valueNode = semantic.nodes.data[valueRoot];
                    valueNode.typeKind = result.kind.value;
                    valueNode.typeName = result.name;
                    valueNode.typePointee = result.pointee;
                    semantic.nodes.data[valueRoot] = valueNode;
                }
            }
        }
        restoreOwnership(semantic, ownershipMerged, ownershipCount);
        k_boot_free(ownershipMerged as unit*);
        k_boot_free(ownershipBefore as unit*);
        val exhaustive = enumWhenExhaustive(
            semantic, subject, roots, branchCount, true);
        if (!hasElse && !exhaustive) {
            semantic.fail(4, node);
        }
        var resolved = semantic.nodes.data[root];
        resolved.typeKind = result.kind.value;
        resolved.typeName = result.name;
        resolved.typePointee = result.pointee;
        semantic.nodes.data[root] = resolved;
        k_boot_free(roots as unit*);
        return result;
    }
    if (node.kind == AstKind.ARRAY_LITERAL) {
        if (node.aux == 0) return invalidType().array(0);
        var childRoot = root - 1;
        var element = expressionType(semantic, childRoot);
        if (element.kind == TypeKind.INTEGER_LITERAL) element = TypeValue(TypeKind.I32, 0, 0);
        for (index in 0..<node.aux) {
            val actual = expressionType(semantic, childRoot);
            if (!element.accepts(actual, semantic.genericArguments)) {
                semantic.fail(4, semantic.nodes.data[childRoot]);
                return invalidType();
            }
            var childNode = semantic.nodes.data[childRoot];
            childNode.typeKind = element.kind.value;
            childNode.typeName = element.name;
            childNode.typePointee = element.pointee;
            semantic.nodes.data[childRoot] = childNode;
            childRoot = childNode.subtreeStart - 1;
        }
        return element.array(node.aux as u64);
    }
    if (node.kind == AstKind.UNIT_LITERAL) return unitType();
    if (node.kind == AstKind.SIZEOF) {
        typeFromNode(semantic, root - 1);
        return TypeValue(TypeKind.U64, 0, 0);
    }
    return invalidType();
}

fn resolveWhenResultType(
    var semantic: Semantic, root: u64, target: TypeValue) {
    var whenNode = semantic.nodes.data[root];
    if (whenNode.kind != AstKind.WHEN_EXPRESSION) return;
    whenNode.typeKind = target.kind.value;
    whenNode.typeName = target.name;
    whenNode.typePointee = target.pointee;
    semantic.nodes.data[root] = whenNode;
    val branchCount = whenNode.whenBranchCount();
    var branchRoot = root - 1;
    for (index in 0..<branchCount) {
        val valueRoot = branchRoot - 1;
        var valueNode = semantic.nodes.data[valueRoot];
        if (valueNode.typeKind == TypeKind.INTEGER_LITERAL.value) {
            valueNode.typeKind = target.kind.value;
            valueNode.typeName = target.name;
            valueNode.typePointee = target.pointee;
            semantic.nodes.data[valueRoot] = valueNode;
        }
        branchRoot = semantic.nodes.data[branchRoot].subtreeStart - 1;
    }
}

fn resolveIfResultType(
    var semantic: Semantic, root: u64, target: TypeValue) {
    var ifNode = semantic.nodes.data[root];
    if (ifNode.kind != AstKind.IF_EXPRESSION) return;
    ifNode.typeKind = target.kind.value;
    ifNode.typeName = target.name;
    ifNode.typePointee = target.pointee;
    semantic.nodes.data[root] = ifNode;
    val elseValueRoot = root - 1;
    var thenValueRoot = semantic.nodes.data[elseValueRoot].subtreeStart - 1;
    val remaining = ifNode.aux / 65536;
    for (index in 0..<remaining) {
        thenValueRoot = semantic.nodes.data[thenValueRoot].subtreeStart - 1;
    }
    var valueNode = semantic.nodes.data[thenValueRoot];
    if (valueNode.typeKind == TypeKind.INTEGER_LITERAL.value) {
        valueNode.typeKind = target.kind.value;
        valueNode.typeName = target.name;
        valueNode.typePointee = target.pointee;
        semantic.nodes.data[thenValueRoot] = valueNode;
    }
    valueNode = semantic.nodes.data[elseValueRoot];
    if (valueNode.typeKind == TypeKind.INTEGER_LITERAL.value) {
        valueNode.typeKind = target.kind.value;
        valueNode.typeName = target.name;
        valueNode.typePointee = target.pointee;
        semantic.nodes.data[elseValueRoot] = valueNode;
    }
}
