struct Semantic(
    source: Source,
    nodes: AstList,
    structs: DeclarationList,
    functions: DeclarationList,
    locals: LocalList,
    genericArguments: TypeValueList,
    result: SemanticResult,
    returnType: TypeValue,
    scopeStart: u64,
    currentFunction: u64,
    currentStruct: u64)

fn sourceHash(source: Source, start: u64, end: u64): u64 {
    var value: u64 = 5381;
    var offset = start;
    while (offset < end) {
        value = value * 33 + source.data[offset] as u64;
        offset = offset + 1;
    }
    return value;
}

fn nodeHash(semantic: Semantic, node: AstNode): u64 {
    return sourceHash(semantic.source, node.start, node.end);
}

fn nodeIsPrint(semantic: Semantic, node: AstNode): bool {
    if (node.end - node.start != 5) { return false; }
    if (semantic.source.data[node.start] != 112) { return false; }
    if (semantic.source.data[node.start + 1] != 114) { return false; }
    if (semantic.source.data[node.start + 2] != 105) { return false; }
    if (semantic.source.data[node.start + 3] != 110) { return false; }
    return semantic.source.data[node.start + 4] == 116;
}

fn declarationFind(list: DeclarationList, name: u64): u64 {
    var index: u64 = 0;
    while (index < list.length) {
        if (list.data[index].name == name) { return index; }
        index = index + 1;
    }
    return list.length;
}

fn localFind(locals: LocalList, name: u64): u64 {
    var index = locals.length;
    while (index > 0) {
        index = index - 1;
        if (locals.data[index].name == name) { return index; }
    }
    return locals.length;
}

fn localFindFrom(locals: LocalList, name: u64, start: u64): u64 {
    var index = locals.length;
    while (index > start) {
        index = index - 1;
        if (locals.data[index].name == name) { return index; }
    }
    return locals.length;
}

fn semanticFail(var semantic: Semantic, category: u32, node: AstNode) {
    if (semantic.result.ok) {
        semantic.result =
            semanticError(category, node, semantic.genericArguments);
    }
}

fn functionIsExtern(function: AstNode): bool {
    return (function.aux / 65536) % 2 == 1;
}

fn functionTypeParameterCount(function: AstNode): u32 {
    return function.aux / 131072;
}

fn constraintFromHash(hash: u64): u32 {
    if (hash == 8246182162010039579) { return 1; }
    if (hash == 229477778387914) { return 2; }
    if (hash == 6953836814478) { return 3; }
    if (hash == 229469892001299) { return 4; }
    if (hash == 7573017822976354) { return 5; }
    if (hash == 210712519067) { return 6; }
    return 0;
}

fn functionTypeParameterRoot(
    semantic: Semantic, functionRoot: u64, position: u32): u64 {
    val function = semantic.nodes.data[functionRoot];
    var root = functionReturnRoot(semantic, functionRoot);
    var parameters = functionParameterCount(function);
    while (parameters > 0) {
        root = semantic.nodes.data[root].subtreeStart - 1;
        parameters = parameters - 1;
    }
    var remaining = functionTypeParameterCount(function);
    while (remaining >= position) {
        root = semantic.nodes.data[root].subtreeStart - 1;
        remaining = remaining - 1;
    }
    return root;
}

fn structTypeParameterCount(structure: AstNode): u32 {
    return structure.aux / 65536;
}

fn structFieldCount(structure: AstNode): u32 {
    return structure.aux % 65536;
}

fn structTypeParameterRoot(
    semantic: Semantic, structureRoot: u64, position: u32): u64 {
    val structure = semantic.nodes.data[structureRoot];
    var root = structureRoot - 1;
    var fields = structFieldCount(structure);
    while (fields > 0) {
        root = semantic.nodes.data[root].subtreeStart - 1;
        fields = fields - 1;
    }
    var remaining = structTypeParameterCount(structure);
    while (remaining > position) {
        root = semantic.nodes.data[root].subtreeStart - 1;
        remaining = remaining - 1;
    }
    return root;
}

fn structTypeParameterPosition(
    semantic: Semantic, structureRoot: u64, name: u64): u32 {
    val count = structTypeParameterCount(
        semantic.nodes.data[structureRoot]);
    var position: u32 = 1;
    while (position <= count) {
        val root = structTypeParameterRoot(
            semantic, structureRoot, position);
        val parameter = semantic.nodes.data[root];
        if (nodeHash(
                semantic,
                semantic.nodes.data[parameter.subtreeStart]) == name) {
            return position - 1;
        }
        position = position + 1;
    }
    return count;
}

fn fieldRootAt(
    nodes: AstList, structureRoot: u64, wanted: u32): u64 {
    val structure = nodes.data[structureRoot];
    var roots =
        k_boot_alloc((structFieldCount(structure) as u64) * sizeof(u64)) as u64*;
    var root = structureRoot - 1;
    var remaining = structFieldCount(structure);
    while (remaining > 0) {
        roots[remaining as u64 - 1] = root;
        root = nodes.data[root].subtreeStart - 1;
        remaining = remaining - 1;
    }
    val result = roots[wanted as u64];
    k_boot_free(roots as unit*);
    return result;
}

fn substituteStructType(
    semantic: Semantic, structureRoot: u64,
    type: TypeValue, arguments: TypeValueList,
    argumentStart: u64, count: u32): TypeValue {
    if (type.kind == 14) {
        val position =
            structTypeParameterPosition(semantic, structureRoot, type.name);
        if (position >= count) { return invalidType(); }
        return arguments.data[argumentStart + position as u64];
    }
    if (type.kind == 8) {
        val start = type.pointee % 65536;
        val argCount = type.pointee / 65536;
        if (argCount == 0) { return type; }
        val newStart = semantic.genericArguments.length;
        var index: u32 = 0;
        while (index < argCount) {
            val arg = semantic.genericArguments.data[start as u64 + index as u64];
            val substituted = substituteStructType(
                semantic, structureRoot, arg, arguments, argumentStart, count);
            var resolved = semantic.genericArguments;
            typeValueListAppend(resolved, substituted);
            semantic.genericArguments = resolved;
            index = index + 1;
        }
        return TypeValue(8, type.name, newStart as u32 + argCount * 65536);
    }
    if (type.kind == 15) {
        val inner = substituteStructType(
            semantic, structureRoot,
            TypeValue(type.pointee, type.name, 0), arguments, argumentStart, count);
        return TypeValue(15, inner.name, inner.kind);
    }
    if (type.kind == 9) {
        val inner = substituteStructType(
            semantic, structureRoot,
            TypeValue(type.pointee, type.name, 0), arguments, argumentStart, count);
        return TypeValue(9, inner.name, inner.kind);
    }
    if (type.kind == 13) {
        val inner = substituteStructType(
            semantic, structureRoot,
            TypeValue(type.pointee, type.name, 0), arguments, argumentStart, count);
        return TypeValue(13, inner.name, inner.kind);
    }
    return type;
}

fn findCurrentTypeParameter(
    semantic: Semantic, name: u64): TypeValue {
    if (semantic.currentFunction < semantic.nodes.length) {
        val function =
            semantic.nodes.data[semantic.currentFunction];
        val count = functionTypeParameterCount(function);
        var position: u32 = 1;
        while (position <= count) {
            val root = functionTypeParameterRoot(
                semantic, semantic.currentFunction, position);
            val parameter = semantic.nodes.data[root];
            val nameNode =
                semantic.nodes.data[parameter.subtreeStart];
            if (nodeHash(semantic, nameNode) == name) {
                var constraint: u32 = 0;
                if (parameter.aux == 1) {
                    constraint = constraintFromHash(
                        nodeHash(
                            semantic,
                            semantic.nodes.data[root - 1]));
                }
                return TypeValue(14, name, constraint);
            }
            position = position + 1;
        }
    }
    if (semantic.currentStruct < semantic.nodes.length) {
        val structure =
            semantic.nodes.data[semantic.currentStruct];
        val count = structTypeParameterCount(structure);
        var position: u32 = 1;
        while (position <= count) {
            val root = structTypeParameterRoot(
                semantic, semantic.currentStruct, position);
            val parameter = semantic.nodes.data[root];
            val nameNode =
                semantic.nodes.data[parameter.subtreeStart];
            if (nodeHash(semantic, nameNode) == name) {
                var constraint: u32 = 0;
                if (parameter.aux == 1) {
                    constraint = constraintFromHash(
                        nodeHash(
                            semantic,
                            semantic.nodes.data[root - 1]));
                }
                return TypeValue(14, name, constraint);
            }
            position = position + 1;
        }
    }
    return invalidType();
}

fn typeParameterPosition(
    semantic: Semantic, functionRoot: u64, name: u64): u32 {
    val count = functionTypeParameterCount(
        semantic.nodes.data[functionRoot]);
    var position: u32 = 1;
    while (position <= count) {
        val root = functionTypeParameterRoot(
            semantic, functionRoot, position);
        val parameter = semantic.nodes.data[root];
        if (nodeHash(
                semantic,
                semantic.nodes.data[parameter.subtreeStart]) == name) {
            return position - 1;
        }
        position = position + 1;
    }
    return count;
}

fn substituteGenericType(
    semantic: Semantic, functionRoot: u64,
    type: TypeValue, arguments: TypeValue*, count: u32): TypeValue {
    if (type.kind == 15) {
        val inner = substituteGenericType(
            semantic, functionRoot,
            TypeValue(type.pointee, type.name, 0), arguments, count);
        if (inner.kind == 0) { return inner; }
        return TypeValue(15, inner.name, inner.kind);
    }
    if (type.kind != 14) { return type; }
    val position =
        typeParameterPosition(semantic, functionRoot, type.name);
    if (position >= count) { return invalidType(); }
    return arguments[position as u64];
}

fn constraintAcceptsType(constraint: u32, type: TypeValue): bool {
    if (constraint == 0) {
        if (type.kind == 0) { return false; }
        if (type.kind == 1) { return false; }
        return true;
    }
    if (type.kind == 14) {
        return type.pointee >= constraint;
    }
    if (constraint == 1) {
        if (type.kind == 2) { return true; }
        if (type.kind >= 3) {
            if (type.kind <= 7) { return true; }
        }
        return type.kind == 11;
    }
    if (constraint == 2) {
        if (type.kind >= 3) {
            if (type.kind <= 7) { return true; }
        }
        return type.kind == 11;
    }
    if (constraint == 3) {
        if (type.kind >= 3) {
            if (type.kind <= 7) { return true; }
        }
        return type.kind == 11;
    }
    if (constraint == 4) {
        if (type.kind >= 3) {
            if (type.kind <= 7) { return true; }
        }
        return type.kind == 11;
    }
    if (constraint == 5) {
        if (type.kind >= 5) {
            if (type.kind <= 7) { return true; }
        }
        return type.kind == 11;
    }
    return false;
}

fn typeFromNode(var semantic: Semantic, root: u64): TypeValue {
    val value = inferTypeFromNode(semantic, root);
    var node = semantic.nodes.data[root];
    node.typeKind = value.kind;
    node.typeName = value.name;
    node.typePointee = value.pointee;
    semantic.nodes.data[root] = node;
    return value;
}

fn structTypeArgumentRoot(
    semantic: Semantic, typeRoot: u64, position: u32, count: u32): u64 {
    var root = typeRoot - 1;
    var remaining = count;
    while (remaining > position) {
        root = semantic.nodes.data[root].subtreeStart - 1;
        remaining = remaining - 1;
    }
    return root;
}

fn inferTypeFromNode(var semantic: Semantic, root: u64): TypeValue {
    val node = semantic.nodes.data[root];
    if (node.kind == 1) {
        val tokenKind = node.aux % 256;
        val primitive = primitiveType(tokenKind);
        if (primitive.kind != 0) { return primitive; }
        val parameter = findCurrentTypeParameter(
            semantic, nodeHash(semantic, node));
        if (parameter.kind != 0) { return parameter; }
        
        val typeArgumentCount = node.aux / 256;
        if (typeArgumentCount > 0) {
            val start = semantic.genericArguments.length;
            val typeArguments = k_boot_alloc((typeArgumentCount as u64) * sizeof(TypeValue)) as TypeValue*;
            var index: u32 = 0;
            while (index < typeArgumentCount) {
                val argRoot = structTypeArgumentRoot(semantic, root, index + 1, typeArgumentCount);
                typeArguments[index as u64] = typeFromNode(semantic, argRoot);
                index = index + 1;
            }
            index = 0;
            while (index < typeArgumentCount) {
                var resolved = semantic.genericArguments;
                typeValueListAppend(resolved, typeArguments[index as u64]);
                semantic.genericArguments = resolved;
                index = index + 1;
            }
            k_boot_free(typeArguments as unit*);
            return TypeValue(8, nodeHash(semantic, node), start as u32 + typeArgumentCount * 65536);
        }
        
        return TypeValue(8, nodeHash(semantic, node), 0);
    }
    if (node.kind == 2) {
        val inner = typeFromNode(semantic, root - 1);
        if (inner.kind == 9) {
            return TypeValue(9, inner.pointee as u64, 9);
        }
        return TypeValue(9, inner.name, inner.kind);
    }
    if (node.kind == 4) {
        val inner = typeFromNode(semantic, root - 1);
        return TypeValue(13, inner.name, inner.kind);
    }
    if (node.kind == 3) {
        val inner = typeFromNode(semantic, root - 1);
        return TypeValue(15, inner.name, inner.kind);
    }
    return invalidType();
}

fn functionReturnRoot(semantic: Semantic, functionRoot: u64): u64 {
    val function = semantic.nodes.data[functionRoot];
    if (functionIsExtern(function)) { return functionRoot - 1; }
    val body = semantic.nodes.data[functionRoot - 1];
    return body.subtreeStart - 1;
}

fn functionParameterRoot(
    semantic: Semantic, functionRoot: u64, position: u32): u64 {
    val function = semantic.nodes.data[functionRoot];
    var root = functionReturnRoot(semantic, functionRoot);
    var remaining = functionParameterCount(function);
    while (remaining >= position) {
        root = semantic.nodes.data[root].subtreeStart - 1;
        remaining = remaining - 1;
    }
    return root;
}

fn functionParameterCount(function: AstNode): u32 {
    return function.aux % 65536;
}

fn expressionType(var semantic: Semantic, root: u64): TypeValue {
    val value = inferExpressionType(semantic, root);
    var node = semantic.nodes.data[root];
    node.typeKind = value.kind;
    node.typeName = value.name;
    node.typePointee = value.pointee;
    semantic.nodes.data[root] = node;
    return value;
}

fn inferExpressionType(var semantic: Semantic, root: u64): TypeValue {
    if (semantic.result.ok == false) { return invalidType(); }
    val node = semantic.nodes.data[root];
    if (node.kind == 10) {
        val name = nodeHash(semantic, node);
        val local = localFind(semantic.locals, name);
        if (local != semantic.locals.length) {
            var resolved = semantic.nodes.data[root];
            resolved.storage = semantic.locals.data[local].storage;
            semantic.nodes.data[root] = resolved;
            return semantic.locals.data[local].valueType;
        }
        if (declarationFind(semantic.functions, name) !=
                semantic.functions.length) {
            return TypeValue(12, name, 0);
        }
        semanticFail(semantic, 2, node);
        return invalidType();
    }
    if (node.kind == 11) {
        if (node.aux == 2) { return integerLiteralType(); }
        if (node.aux == 5) { return TypeValue(10, 0, 0); }
        if (node.aux == 29) { return boolType(); }
        if (node.aux == 30) { return boolType(); }
        if (node.aux == 31) { return TypeValue(16, 0, 0); }
        return invalidType();
    }
    if (node.kind == 12) {
        val operand = expressionType(semantic, root - 1);
        if (node.aux == 62) {
            if (operand.kind != 9) {
                semanticFail(semantic, 4, node);
                return invalidType();
            }
            if (operand.pointee == 9) {
                return TypeValue(9, 0, operand.name as u32);
            }
            return TypeValue(operand.pointee, operand.name, 0);
        }
        if (node.aux == 68) {
            if (operand.kind == 9) {
                return TypeValue(9, operand.pointee as u64, 9);
            }
            return TypeValue(9, operand.name, operand.kind);
        }
        return operand;
    }
    if (node.kind == 13) {
        val rightRoot = root - 1;
        val leftRoot = semantic.nodes.data[rightRoot].subtreeStart - 1;
        val left = expressionType(semantic, leftRoot);
        val right = expressionType(semantic, rightRoot);
        var comparison = node.aux == 66;
        if (node.aux == 67) { comparison = true; }
        if (node.aux >= 79) {
            if (node.aux <= 84) {
                comparison = true;
            }
        }
        if (comparison) {
            if (typeAccepts(left, right, semantic.genericArguments) == false) {
                if (typeAccepts(right, left, semantic.genericArguments) == false) {
                    semanticFail(semantic, 4, node);
                }
            }
            return boolType();
        }
        if (typeAccepts(left, right, semantic.genericArguments)) { return left; }
        if (typeAccepts(right, left, semantic.genericArguments)) { return right; }
        semanticFail(semantic, 4, node);
        return invalidType();
    }
    if (node.kind == 14) {
        val rightRoot = root - 1;
        val leftRoot = semantic.nodes.data[rightRoot].subtreeStart - 1;
        val target = semantic.nodes.data[leftRoot];
        if (target.kind == 10) {
            val local = localFind(
                semantic.locals, nodeHash(semantic, target));
            if (local == semantic.locals.length) {
                semanticFail(semantic, 2, target);
                return invalidType();
            }
            if (semantic.locals.data[local].mutable == false) {
                semanticFail(semantic, 7, target);
                return invalidType();
            }
        }
        val left = expressionType(semantic, leftRoot);
        val right = expressionType(semantic, rightRoot);
        if (typeAccepts(left, right, semantic.genericArguments) == false) {
            semanticFail(semantic, 4, node);
        }
        return left;
    }
    if (node.kind == 15) {
        val typeRoot = root - 1;
        val valueRoot = semantic.nodes.data[typeRoot].subtreeStart - 1;
        expressionType(semantic, valueRoot);
        return typeFromNode(semantic, typeRoot);
    }
    if (node.kind == 16) {
        val argumentCount = node.aux % 65536;
        val explicitTypeCount = node.aux / 65536;
        val argumentRoots =
            k_boot_alloc(
                (argumentCount as u64) * sizeof(u64)) as u64*;
        var cursor = root - 1;
        var argument = argumentCount;
        while (argument > 0) {
            argumentRoots[argument as u64 - 1] = cursor;
            cursor = semantic.nodes.data[cursor].subtreeStart - 1;
            argument = argument - 1;
        }
        val explicitTypeRoots =
            k_boot_alloc(
                (explicitTypeCount as u64) * sizeof(u64)) as u64*;
        var explicit = explicitTypeCount;
        while (explicit > 0) {
            explicitTypeRoots[explicit as u64 - 1] = cursor;
            cursor = semantic.nodes.data[cursor].subtreeStart - 1;
            explicit = explicit - 1;
        }
        val callee = semantic.nodes.data[cursor];
        if (callee.kind != 10) {
            semanticFail(semantic, 2, callee);
            k_boot_free(explicitTypeRoots as unit*);
            k_boot_free(argumentRoots as unit*);
            return invalidType();
        }
        val functionIndex = declarationFind(
            semantic.functions, nodeHash(semantic, callee));
        if (functionIndex == semantic.functions.length) {
            if (nodeIsPrint(semantic, callee)) {
                if (argumentCount != 1) {
                    semanticFail(semantic, 3, callee);
                    k_boot_free(explicitTypeRoots as unit*);
                    k_boot_free(argumentRoots as unit*);
                    return invalidType();
                }
                expressionType(semantic, argumentRoots[0]);
                k_boot_free(explicitTypeRoots as unit*);
                k_boot_free(argumentRoots as unit*);
                return unitType();
            }
            val structureIndex = declarationFind(
                semantic.structs, nodeHash(semantic, callee));
            if (structureIndex == semantic.structs.length) {
                semanticFail(semantic, 2, callee);
                k_boot_free(explicitTypeRoots as unit*);
                k_boot_free(argumentRoots as unit*);
                return invalidType();
            }
            val structureRoot =
                semantic.structs.data[structureIndex].node;
            val structure = semantic.nodes.data[structureRoot];
            val fieldCount = structFieldCount(structure);
            val typeCount = structTypeParameterCount(structure);
            if (fieldCount != argumentCount) {
                semanticFail(semantic, 3, callee);
                k_boot_free(explicitTypeRoots as unit*);
                k_boot_free(argumentRoots as unit*);
                return invalidType();
            }
            if (explicitTypeCount > 0) {
                if (explicitTypeCount != typeCount) {
                    semanticFail(semantic, 3, callee);
                    k_boot_free(explicitTypeRoots as unit*);
                    k_boot_free(argumentRoots as unit*);
                    return invalidType();
                }
            }
            val typeArguments =
                k_boot_alloc(
                    (typeCount as u64) * sizeof(TypeValue)) as TypeValue*;
            explicit = 0;
            while (explicit < typeCount) {
                typeArguments[explicit as u64] = invalidType();
                explicit = explicit + 1;
            }
            explicit = 0;
            while (explicit < explicitTypeCount) {
                typeArguments[explicit as u64] =
                    typeFromNode(
                        semantic,
                        explicitTypeRoots[explicit as u64]);
                explicit = explicit + 1;
            }
            argument = 0;
            while (argument < argumentCount) {
                var actual = expressionType(
                    semantic, argumentRoots[argument as u64]);
                val fieldRoot = fieldRootAt(semantic.nodes, structureRoot, argument);
                val savedStruct = semantic.currentStruct;
                semantic.currentStruct = structureRoot;
                val pattern = typeFromNode(semantic, fieldRoot - 1);
                semantic.currentStruct = savedStruct;
                if (pattern.kind == 14) {
                    val position = structTypeParameterPosition(
                        semantic, structureRoot, pattern.name);
                    if (explicitTypeCount == 0) {
                        var inferredActual = actual;
                        if (inferredActual.kind == 11) {
                            inferredActual = TypeValue(3, 0, 0);
                        }
                        if (typeArguments[position as u64].kind == 0) {
                            typeArguments[position as u64] = inferredActual;
                        } else {
                            if (typeEquals(
                                    typeArguments[position as u64],
                                    inferredActual, semantic.genericArguments) == false) {
                                semanticFail(
                                    semantic, 4,
                                    semantic.nodes.data[
                                        argumentRoots[argument as u64]]);
                            }
                        }
                    }
                } else {
                    if (actual.kind == 11) {
                        if (pattern.kind >= 3) {
                            if (pattern.kind <= 7) {
                                actual = pattern;
                            }
                        }
                    }
                }
                val expected = substituteStructType(
                    semantic, structureRoot, pattern,
                    TypeValueList(typeArguments, typeCount as u64, typeCount as u64),
                    0, typeCount);
                if (typeAccepts(expected, actual, semantic.genericArguments) == false) {
                    semanticFail(
                        semantic, 4,
                        semantic.nodes.data[
                            argumentRoots[argument as u64]]);
                }
                argument = argument + 1;
            }
            explicit = 0;
            while (explicit < typeCount) {
                val parameterRoot = structTypeParameterRoot(
                    semantic, structureRoot, explicit + 1);
                val parameter = semantic.nodes.data[parameterRoot];
                var constraint: u32 = 0;
                if (parameter.aux == 1) {
                    constraint = constraintFromHash(
                        nodeHash(
                            semantic,
                            semantic.nodes.data[parameterRoot - 1]));
                }
                if (constraintAcceptsType(
                        constraint,
                        typeArguments[explicit as u64]) == false) {
                    semanticFail(semantic, 4, callee);
                }
                explicit = explicit + 1;
            }
            var start: u32 = 0;
            if (typeCount > 0) {
                start = semantic.genericArguments.length as u32;
                var callNode = semantic.nodes.data[root];
                callNode.genericArgumentStart = start as u64;
                callNode.genericArgumentCount = typeCount;
                var typeIndex: u32 = 0;
                while (typeIndex < typeCount) {
                    var resolved = semantic.genericArguments;
                    typeValueListAppend(
                        resolved, typeArguments[typeIndex as u64]);
                    semantic.genericArguments = resolved;
                    typeIndex = typeIndex + 1;
                }
                semantic.nodes.data[root] = callNode;
            }
            k_boot_free(typeArguments as unit*);
            k_boot_free(explicitTypeRoots as unit*);
            k_boot_free(argumentRoots as unit*);
            return TypeValue(
                8, semantic.structs.data[structureIndex].name, start + typeCount * 65536);
        }
        val functionRoot = semantic.functions.data[functionIndex].node;
        val function = semantic.nodes.data[functionRoot];
        if (functionParameterCount(function) != argumentCount) {
            semanticFail(semantic, 3, callee);
            k_boot_free(explicitTypeRoots as unit*);
            k_boot_free(argumentRoots as unit*);
            return invalidType();
        }
        val typeCount = functionTypeParameterCount(function);
        if (explicitTypeCount > 0) {
            if (explicitTypeCount != typeCount) {
                semanticFail(semantic, 3, callee);
                k_boot_free(explicitTypeRoots as unit*);
                k_boot_free(argumentRoots as unit*);
                return invalidType();
            }
        }
        val typeArguments =
            k_boot_alloc(
                (typeCount as u64) * sizeof(TypeValue)) as TypeValue*;
        explicit = 0;
        while (explicit < typeCount) {
            typeArguments[explicit as u64] = invalidType();
            explicit = explicit + 1;
        }
        explicit = 0;
        while (explicit < explicitTypeCount) {
            typeArguments[explicit as u64] =
                typeFromNode(
                    semantic,
                    explicitTypeRoots[explicit as u64]);
            explicit = explicit + 1;
        }
        argument = 0;
        while (argument < argumentCount) {
            val actual = expressionType(
                semantic, argumentRoots[argument as u64]);
            val parameterRoot =
                functionParameterRoot(
                    semantic, functionRoot, argument + 1);
            val savedFunction = semantic.currentFunction;
            semantic.currentFunction = functionRoot;
            val pattern = typeFromNode(semantic, parameterRoot - 1);
            semantic.currentFunction = savedFunction;
            if (pattern.kind == 14) {
                val position = typeParameterPosition(
                    semantic, functionRoot, pattern.name);
                if (explicitTypeCount == 0) {
                    var inferredActual = actual;
                    if (inferredActual.kind == 11) {
                        inferredActual = TypeValue(3, 0, 0);
                    }
                    if (typeArguments[position as u64].kind == 0) {
                        typeArguments[position as u64] = inferredActual;
                    } else {
                        if (typeEquals(
                                typeArguments[position as u64],
                                inferredActual, semantic.genericArguments) == false) {
                            semanticFail(
                                semantic, 4,
                                semantic.nodes.data[
                                    argumentRoots[argument as u64]]);
                        }
                    }
                }
            }
            val expected = substituteGenericType(
                semantic, functionRoot, pattern,
                typeArguments, typeCount);
            if (typeAccepts(expected, actual, semantic.genericArguments) == false) {
                semanticFail(
                    semantic, 4,
                    semantic.nodes.data[
                        argumentRoots[argument as u64]]);
            }
            argument = argument + 1;
        }
        explicit = 0;
        while (explicit < typeCount) {
            val parameterRoot = functionTypeParameterRoot(
                semantic, functionRoot, explicit + 1);
            val parameter = semantic.nodes.data[parameterRoot];
            var constraint: u32 = 0;
            if (parameter.aux == 1) {
                constraint = constraintFromHash(
                    nodeHash(
                        semantic,
                        semantic.nodes.data[parameterRoot - 1]));
            }
            if (constraintAcceptsType(
                    constraint,
                    typeArguments[explicit as u64]) == false) {
                semanticFail(semantic, 4, callee);
            }
            explicit = explicit + 1;
        }
        val savedFunction = semantic.currentFunction;
        semantic.currentFunction = functionRoot;
        val returnPattern = typeFromNode(
            semantic, functionReturnRoot(semantic, functionRoot));
        semantic.currentFunction = savedFunction;
        val returnType = substituteGenericType(
            semantic, functionRoot, returnPattern,
            typeArguments, typeCount);
        if (typeCount > 0) {
            var callNode = semantic.nodes.data[root];
            callNode.genericArgumentStart =
                semantic.genericArguments.length;
            callNode.genericArgumentCount = typeCount;
            var typeIndex: u32 = 0;
            while (typeIndex < typeCount) {
                var resolved = semantic.genericArguments;
                typeValueListAppend(
                    resolved, typeArguments[typeIndex as u64]);
                semantic.genericArguments = resolved;
                typeIndex = typeIndex + 1;
            }
            semantic.nodes.data[root] = callNode;
        }
        k_boot_free(typeArguments as unit*);
        k_boot_free(explicitTypeRoots as unit*);
        k_boot_free(argumentRoots as unit*);
        return returnType;
    }
    if (node.kind == 17) {
        val objectRoot = root - 1;
        val object = expressionType(semantic, objectRoot);
        if (object.kind != 8) {
            semanticFail(semantic, 8, node);
            return invalidType();
        }
        val structureIndex =
            declarationFind(semantic.structs, object.name);
        if (structureIndex == semantic.structs.length) {
            semanticFail(semantic, 8, node);
            return invalidType();
        }
        val structureRoot = semantic.structs.data[structureIndex].node;
        val structure = semantic.nodes.data[structureRoot];
        val wanted = nodeHash(semantic, node);
        var cursor = structureRoot - 1;
        var remaining = structFieldCount(structure);
        while (remaining > 0) {
            val field = semantic.nodes.data[cursor];
            val fieldName = semantic.nodes.data[field.subtreeStart];
            if (nodeHash(semantic, fieldName) == wanted) {
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
            remaining = remaining - 1;
        }
        semanticFail(semantic, 8, node);
        return invalidType();
    }
    if (node.kind == 18) {
        val indexRoot = root - 1;
        val objectRoot = semantic.nodes.data[indexRoot].subtreeStart - 1;
        val object = expressionType(semantic, objectRoot);
        expressionType(semantic, indexRoot);
        if (object.kind != 9) {
            semanticFail(semantic, 8, node);
            return invalidType();
        }
        if (object.pointee == 9) {
            return TypeValue(9, 0, object.name as u32);
        }
        return TypeValue(object.pointee, object.name, 0);
    }
    if (node.kind == 19) {
        val operand = expressionType(semantic, root - 1);
        if (operand.kind != 15) {
            semanticFail(semantic, 4, node);
            return invalidType();
        }
        return TypeValue(operand.pointee, operand.name, 0);
    }
    if (node.kind == 20) { return unitType(); }
    if (node.kind == 21) {
        typeFromNode(semantic, root - 1);
        return TypeValue(7, 0, 0);
    }
    return invalidType();
}

fn checkBlock(var semantic: Semantic, root: u64) {
    val savedLocals = semantic.locals.length;
    val savedScopeStart = semantic.scopeStart;
    semantic.scopeStart = savedLocals;
    val block = semantic.nodes.data[root];
    val roots =
        k_boot_alloc((block.aux as u64) * sizeof(u64)) as u64*;
    var statementRoot = root - 1;
    var remaining = block.aux;
    while (remaining > 0) {
        roots[remaining as u64 - 1] = statementRoot;
        statementRoot =
            semantic.nodes.data[statementRoot].subtreeStart - 1;
        remaining = remaining - 1;
    }
    var index: u32 = 0;
    while (index < block.aux) {
        checkStatement(semantic, roots[index as u64]);
        index = index + 1;
    }
    k_boot_free(roots as unit*);
    var restoredLocals = semantic.locals;
    restoredLocals.length = savedLocals;
    semantic.locals = restoredLocals;
    semantic.scopeStart = savedScopeStart;
}

fn checkStatement(var semantic: Semantic, root: u64) {
    if (semantic.result.ok == false) { return; }
    val node = semantic.nodes.data[root];
    if (node.kind == 30) {
        checkBlock(semantic, root);
        return;
    }
    if (node.kind == 31) {
        var branchRoot = root - 1;
        if (node.aux == 1) {
            checkBlock(semantic, branchRoot);
            branchRoot =
                semantic.nodes.data[branchRoot].subtreeStart - 1;
        }
        checkBlock(semantic, branchRoot);
        val conditionRoot =
            semantic.nodes.data[branchRoot].subtreeStart - 1;
        if (expressionType(semantic, conditionRoot).kind != 2) {
            semanticFail(
                semantic, 6, semantic.nodes.data[conditionRoot]);
        }
        return;
    }
    if (node.kind == 32) {
        val bodyRoot = root - 1;
        checkBlock(semantic, bodyRoot);
        val conditionRoot =
            semantic.nodes.data[bodyRoot].subtreeStart - 1;
        if (expressionType(semantic, conditionRoot).kind != 2) {
            semanticFail(
                semantic, 6, semantic.nodes.data[conditionRoot]);
        }
        return;
    }
    if (node.kind == 33) {
        val initializerRoot = root - 1;
        val initializer = expressionType(semantic, initializerRoot);
        val nameNode = semantic.nodes.data[node.subtreeStart];
        val name = nodeHash(semantic, nameNode);
        if (localFindFrom(
                semantic.locals, name, semantic.scopeStart) !=
                semantic.locals.length) {
            semanticFail(semantic, 1, nameNode);
            return;
        }
        var valueType = initializer;
        val afterName = node.subtreeStart + 1;
        if (afterName < semantic.nodes.data[initializerRoot].subtreeStart) {
            valueType = typeFromNode(
                semantic,
                semantic.nodes.data[initializerRoot].subtreeStart - 1);
            if (typeAccepts(valueType, initializer, semantic.genericArguments) == false) {
                semanticFail(
                    semantic, 4, semantic.nodes.data[initializerRoot]);
            }
        }
        var locals = semantic.locals;
        localListAppend(
            locals,
            LocalInfo(
                name, valueType, node.aux == 7, nameNode.start));
        semantic.locals = locals;
        return;
    }
    if (node.kind == 34) {
        var actual = unitType();
        if (node.aux == 1) {
            actual = expressionType(semantic, root - 1);
        }
        if (typeAccepts(semantic.returnType, actual, semantic.genericArguments) == false) {
            if (node.aux == 1) {
                semanticFail(
                    semantic, 5, semantic.nodes.data[root - 1]);
            } else {
                semanticFail(semantic, 5, node);
            }
        } else {
            if (node.aux == 1) {
                var returnNode = semantic.nodes.data[root];
                returnNode.typeKind = semantic.returnType.kind;
                returnNode.typeName = semantic.returnType.name;
                returnNode.typePointee = semantic.returnType.pointee;
                if (semantic.returnType.kind == 15) {
                    if (actual.kind == 16) {
                        returnNode.conversionKind = 2;
                    } else {
                        if (actual.kind != 15) {
                            returnNode.conversionKind = 1;
                        }
                    }
                }
                semantic.nodes.data[root] = returnNode;
                var valueNode = semantic.nodes.data[root - 1];
                if (valueNode.typeKind == 11) {
                    valueNode.typeKind = semantic.returnType.kind;
                    valueNode.typeName = semantic.returnType.name;
                    valueNode.typePointee = semantic.returnType.pointee;
                    semantic.nodes.data[root - 1] = valueNode;
                }
            }
        }
        return;
    }
    if (node.kind == 35) {
        expressionType(semantic, root - 1);
    }
}

fn checkFunction(var semantic: Semantic, root: u64) {
    val function = semantic.nodes.data[root];
    semantic.currentFunction = root;
    if (functionIsExtern(function)) {
        typeFromNode(semantic, functionReturnRoot(semantic, root));
        var externPosition: u32 = 0;
        val externCount = functionParameterCount(function);
        while (externPosition < externCount) {
            val externParameterRoot =
                functionParameterRoot(
                    semantic, root, externPosition + 1);
            typeFromNode(semantic, externParameterRoot - 1);
            externPosition = externPosition + 1;
        }
        return;
    }
    var emptyLocals = semantic.locals;
    emptyLocals.length = 0;
    semantic.locals = emptyLocals;
    semantic.scopeStart = 0;
    semantic.returnType =
        typeFromNode(semantic, functionReturnRoot(semantic, root));
    var position: u32 = 0;
    val count = functionParameterCount(function);
    while (position < count) {
        val parameterRoot =
            functionParameterRoot(semantic, root, position + 1);
        val parameter = semantic.nodes.data[parameterRoot];
        val nameNode = semantic.nodes.data[parameter.subtreeStart];
        val mutable = parameter.aux == 2;
        val parameterName = nodeHash(semantic, nameNode);
        if (localFindFrom(
                semantic.locals, parameterName, 0) !=
                semantic.locals.length) {
            semanticFail(semantic, 1, nameNode);
            return;
        }
        var locals = semantic.locals;
        localListAppend(
            locals,
            LocalInfo(
                parameterName,
                typeFromNode(semantic, parameterRoot - 1),
                mutable,
                nameNode.start));
        semantic.locals = locals;
        position = position + 1;
    }
    checkBlock(semantic, root - 1);
}

fn collectDeclarations(var semantic: Semantic, programRoot: u64) {
    val program = semantic.nodes.data[programRoot];
    val roots =
        k_boot_alloc((program.aux as u64) * sizeof(u64)) as u64*;
    var root = programRoot - 1;
    var remaining = program.aux;
    while (remaining > 0) {
        roots[remaining as u64 - 1] = root;
        root = semantic.nodes.data[root].subtreeStart - 1;
        remaining = remaining - 1;
    }
    var index: u32 = 0;
    while (index < program.aux) {
        root = roots[index as u64];
        val declaration = semantic.nodes.data[root];
        val nameNode = semantic.nodes.data[declaration.subtreeStart];
        val name = nodeHash(semantic, nameNode);
        if (declaration.kind == 43) {
            if (declarationFind(semantic.structs, name) !=
                    semantic.structs.length) {
                semanticFail(semantic, 1, nameNode);
            } else {
                var structures = semantic.structs;
                declarationListAppend(
                    structures, DeclarationInfo(name, root));
                semantic.structs = structures;
            }
            var fieldRoot = root - 1;
            var fields = structFieldCount(declaration);
            val savedStruct = semantic.currentStruct;
            semantic.currentStruct = root;
            while (fields > 0) {
                typeFromNode(semantic, fieldRoot - 1);
                fieldRoot =
                    semantic.nodes.data[fieldRoot].subtreeStart - 1;
                fields = fields - 1;
            }
            semantic.currentStruct = savedStruct;
        } else {
            if (declarationFind(semantic.functions, name) !=
                    semantic.functions.length) {
                semanticFail(semantic, 1, nameNode);
            } else {
                var functions = semantic.functions;
                declarationListAppend(
                    functions, DeclarationInfo(name, root));
                semantic.functions = functions;
            }
        }
        index = index + 1;
    }
    k_boot_free(roots as unit*);
}

fn analyze(source: Source, nodes: AstList): SemanticResult {
    val genericArguments = typeValueListNew();
    var semantic = Semantic(
        source, nodes, declarationListNew(), declarationListNew(),
        localListNew(), genericArguments,
        semanticSuccess(genericArguments), unitType(), 0, nodes.length, nodes.length);
    val programRoot = nodes.length - 1;
    collectDeclarations(semantic, programRoot);
    if (semantic.result.ok) {
        val program = nodes.data[programRoot];
        var root = programRoot - 1;
        var remaining = program.aux;
        while (remaining > 0) {
            if (nodes.data[root].kind == 41) {
                checkFunction(semantic, root);
            }
            root = nodes.data[root].subtreeStart - 1;
            remaining = remaining - 1;
        }
    }
    var result = semantic.result;
    result.genericArguments = semantic.genericArguments;
    localListFree(semantic.locals);
    declarationListFree(semantic.functions);
    declarationListFree(semantic.structs);
    return result;
}
