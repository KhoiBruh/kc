module kbootstrap.semantic;

import kbootstrap.*;

struct Semantic(
    source: Source,
    nodes: AstList,
    structs: DeclarationList,
    enums: DeclarationList,
    functions: DeclarationList,
    constants: DeclarationList,
    locals: LocalList,
    genericArguments: TypeValueList,
    result: SemanticResult,
    returnType: TypeValue,
    scopeStart: u64,
    currentFunction: u64,
    currentStruct: u64,
    loopDepth: u32,
    mutationRoot: u64
)

struct IntegerConstant(ok: bool, negative: bool, overflow: bool, magnitude: u64)

fn sourceHash(source: Source, start: u64, end: u64): u64 {
    var value: u64 = 5381;
    for (i in start..<end) value = value * 33 + source.data[i] as u64;
    return value;
}

fn nodeHash(semantic: Semantic, node: AstNode) =>
    sourceHash(semantic.source, node.start, node.end);

fn integerConstant(semantic: Semantic, root: u64): IntegerConstant {
    var node = semantic.nodes.data[root];
    var negative = false;
    if (node.kind == 12) {
        if (node.aux != 60) {
            if (node.aux != 61) {
                return IntegerConstant(false, false, false, 0);
            }
        }
        negative = node.aux == 61;
        node = semantic.nodes.data[root - 1];
    }
    if (node.kind != 11) return IntegerConstant(false, false, false, 0);
    if (node.aux != 2) return IntegerConstant(false, false, false, 0);
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

fn floatConstant(semantic: Semantic, root: u64): IntegerConstant {
    var node = semantic.nodes.data[root];
    var negative = false;
    if (node.kind == 12) {
        if (node.aux != 60) {
            if (node.aux != 61) {
                return IntegerConstant(false, false, false, 0);
            }
        }
        negative = node.aux == 61;
        node = semantic.nodes.data[root - 1];
    }
    if (node.kind != 11) {
        return IntegerConstant(false, false, false, 0);
    }
    if (node.aux != 3) return IntegerConstant(false, false, false, 0);
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
                if (!sawDecimal) decimalDigits = decimalDigits + 1;
            }
            offset = offset + 1;
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
            offset = offset + 1;
        }
        while (offset < node.end) {
            if (exponent < 1000) {
                exponent = exponent * 10 +
                    (semantic.source.data[offset] - 48) as i64;
            }
            offset = offset + 1;
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
            digitIndex = digitIndex + 1;
        }
        offset = offset + 1;
    }
    while (digitIndex < integerDigits) {
        if (magnitude > 1844674407370955161) overflow = true;
        if (!overflow) magnitude = magnitude * 10;
        digitIndex = digitIndex + 1;
    }
    return IntegerConstant(true, negative, overflow, magnitude);
}

fn integerConstantFits(value: IntegerConstant, target: TypeValue): bool {
    if (value.overflow) return false;
    if (value.negative) {
        if (value.magnitude == 0) return true;
        if (!target.isSigned()) return false;
        if (target.kind == 4) {
            return value.magnitude <= 9223372036854775808;
        }
        return value.magnitude <= 2147483648;
    }
    if (target.kind == 5) return value.magnitude <= 255;
    if (target.kind == 6) return value.magnitude <= 4294967295;
    if (target.kind == 3) return value.magnitude <= 2147483647;
    if (target.kind == 4) return value.magnitude <= 9223372036854775807;
    return true;
}

fn nodeIsPrint(semantic: Semantic, node: AstNode): bool {
    if (node.end - node.start != 5) return false;
    if (semantic.source.data[node.start] != 112) return false;
    if (semantic.source.data[node.start + 1] != 114) return false;
    if (semantic.source.data[node.start + 2] != 105) return false;
    if (semantic.source.data[node.start + 3] != 110) return false;
    return semantic.source.data[node.start + 4] == 116;
}

fn declarationFind(list: DeclarationList, name: u64): u64 {
    for (i in 0..<list.length) if (list.data[i].name == name) return i;
    return list.length;
}

fn localFind(locals: LocalList, name: u64): u64 {
    var index = locals.length;
    while (index > 0) {
        index = index - 1;
        if (locals.data[index].name == name) return index;
    }
    return locals.length;
}

fn localFindFrom(locals: LocalList, name: u64, start: u64): u64 {
    var index = locals.length;
    while (index > start) {
        index = index - 1;
        if (locals.data[index].name == name) return index;
    }
    return locals.length;
}

fn semanticFail(var semantic: Semantic, category: u32, node: AstNode) =>
    if (semantic.result.ok) 
        semantic.result = semanticError(category, node, semantic.genericArguments);

fn whenConditionRoot(semantic: Semantic, branchRoot: u64, valueForm: bool): u64 {
    if (!valueForm) {
        val bodyRoot = branchRoot - 1;
        return semantic.nodes.data[bodyRoot].subtreeStart - 1;
    }
    val branch = semantic.nodes.data[branchRoot];
    val valueRoot = branchRoot - 1;
    var conditionRoot = semantic.nodes.data[valueRoot].subtreeStart - 1;
    var statements = (branch.aux % 65536) / 2;
    while (statements > 0) {
        conditionRoot = semantic.nodes.data[conditionRoot].subtreeStart - 1;
        statements = statements - 1;
    }
    return conditionRoot;
}

fn whenPatternRoot(
    semantic: Semantic, branchRoot: u64, 
    valueForm: bool, patternIndex: u32
): u64 {
    val branch = semantic.nodes.data[branchRoot];
    val patternCount = branch.aux / 65536;
    var root = whenConditionRoot(semantic, branchRoot, valueForm);
    var remaining = patternCount - patternIndex - 1;
    while (remaining > 0) {
        root = semantic.nodes.data[root].subtreeStart - 1;
        remaining = remaining - 1;
    }
    return root;
}

fn enumWhenExhaustive(
    var semantic: Semantic, subject: TypeValue, 
    roots: u64*, branchCount: u32, valueForm: bool
): bool {
    if (subject.kind != 20) return false;
    val enumIndex = declarationFind(semantic.enums, subject.name);
    if (enumIndex == semantic.enums.length) return false;
    val declaration = semantic.nodes.data[semantic.enums.data[enumIndex].node];
    var unique: u32 = 0;
    var index: u32 = 0;
    while (index < branchCount) {
        val branch = semantic.nodes.data[roots[index as u64]];
        val isElse = branch.aux % 2 == 1;

        if (!isElse) {
          var patternIndex: u32 = 0;
          val patternCount = branch.aux / 65536;
          while (patternIndex < patternCount) {
            val conditionRoot = whenPatternRoot(
                semantic, roots[index as u64], valueForm, patternIndex);
            val condition = semantic.nodes.data[conditionRoot];
            if (condition.kind == 17 && condition.typeKind == 20 &&
                    condition.typeName == subject.name) {
                var prior: u32 = 0;
                while (prior <= index) {
                    val priorBranch = semantic.nodes.data[roots[prior as u64]];
                    val priorElse = priorBranch.aux % 2 == 1;
                    if (!priorElse) {
                      var priorPattern: u32 = 0;
                      var priorCount = priorBranch.aux / 65536;
                      if (prior == index) priorCount = patternIndex;
                      while (priorPattern < priorCount) {
                        val priorRoot = whenPatternRoot(
                            semantic, roots[prior as u64], valueForm,
                            priorPattern);
                        val priorCondition = semantic.nodes.data[priorRoot];
                        if (priorCondition.kind == 17 &&
                                priorCondition.typeKind == 20 &&
                                priorCondition.typeName == subject.name &&
                                priorCondition.storage == condition.storage) {
                            var diagnostic = condition;
                            diagnostic.start = semantic.nodes.data[
                                condition.subtreeStart].start;
                            semanticFail(semantic, 1, diagnostic);
                            return false;
                        }
                        priorPattern = priorPattern + 1;
                      }
                    }
                    prior = prior + 1;
                }
                unique = unique + 1;
            }
            patternIndex = patternIndex + 1;
          }
        }
        index = index + 1;
    }

    return unique == declaration.aux;
}

fn functionIsExtern(function: AstNode) => (function.aux / 65536) % 2 == 1;

fn functionInfersReturn(function: AstNode) => (function.storage / 2) % 2 == 1;

fn inferFunctionReturn(var semantic: Semantic, functionRoot: u64): TypeValue {
    var function = semantic.nodes.data[functionRoot];
    if ((function.storage / 8) % 2 == 1)
        return TypeValue(function.typeKind, function.typeName, function.typePointee);
    if ((function.storage / 4) % 2 == 1) {
        semanticFail(semantic, 4, function);
        return invalidType();
    }
    function.storage = function.storage + 4;
    semantic.nodes.data[functionRoot] = function;
    val savedLength = semantic.locals.length;
    val savedScope = semantic.scopeStart;
    val savedFunction = semantic.currentFunction;
    val savedReturn = semantic.returnType;
    semantic.currentFunction = functionRoot;
    for (position in 0..<functionParameterCount(function)) {
        val parameterRoot = functionParameterRoot(semantic, functionRoot, position + 1);
        val parameter = semantic.nodes.data[parameterRoot];
        val nameNode = semantic.nodes.data[parameter.subtreeStart];
        var locals = semantic.locals;
        localListAppend(
            locals,
            LocalInfo(
                nodeHash(semantic, nameNode),
                typeFromNode(semantic, parameterRoot - 1),
                parameter.aux != 1, nameNode.start));
        semantic.locals = locals;
    }
    val statementRoot = functionRoot - 2;
    val statement = semantic.nodes.data[statementRoot];
    var inferred = unitType();
    if (statement.kind == 34) {
        val expressionRoot = statementRoot - 1;
        inferred = expressionType(semantic, expressionRoot);
        if (inferred.kind == 1 || semantic.nodes.data[expressionRoot].kind == 14) {
            inferred = unitType();
            var expressionStatement = statement;
            expressionStatement.kind = 35;
            semantic.nodes.data[statementRoot] = expressionStatement;
        }
    } else {
        semantic.returnType = unitType();
        checkStatement(semantic, statementRoot);
    }
    function = semantic.nodes.data[functionRoot];
    function.typeKind = inferred.kind;
    function.typeName = inferred.name;
    function.typePointee = inferred.pointee;
    function.storage = function.storage - 4 + 8;
    semantic.nodes.data[functionRoot] = function;
    var locals = semantic.locals;
    locals.length = savedLength;
    semantic.locals = locals;
    semantic.scopeStart = savedScope;
    semantic.currentFunction = savedFunction;
    semantic.returnType = savedReturn;
    return inferred;
}

fn functionReturnTypeValue(var semantic: Semantic, functionRoot: u64): TypeValue {
    val function = semantic.nodes.data[functionRoot];
    
    return if (functionInfersReturn(function))
            inferFunctionReturn(semantic, functionRoot)
        else typeFromNode(semantic, functionReturnRoot(semantic, functionRoot));
}

fn functionTypeParameterCount(function: AstNode) => function.aux / 131072;

fn constraintFromHash(hash: u64): u32 => when (hash) {
    8246182162010039579 -> 1;
    229477778387914 -> 2;
    6953836814478 -> 3;
    229469892001299 -> 4;
    7573017822976354 -> 5;
    210712519067 -> 6;
    else -> 0;
};

fn functionTypeParameterRoot(semantic: Semantic, functionRoot: u64, position: u32): u64 {
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

fn structTypeParameterCount(structure: AstNode) => structure.aux / 65536;

fn structFieldCount(structure: AstNode) => structure.aux % 65536;

fn structMethodCount(structure: AstNode) => structure.storage;

fn rootBeforeStructMethods(nodes: AstList, structureRoot: u64): u64 {
    var root = structureRoot - 1;
    var remaining = structMethodCount(nodes.data[structureRoot]);
    while (remaining > 0) {
        root = nodes.data[root].subtreeStart - 1;
        remaining = remaining - 1;
    }
    return root;
}

fn methodHash(owner: u64, name: u64) => owner * 33 + name;

fn structTypeParameterRoot(semantic: Semantic, structureRoot: u64, position: u32): u64 {
    val structure = semantic.nodes.data[structureRoot];
    var root = rootBeforeStructMethods(semantic.nodes, structureRoot);
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

fn structTypeParameterPosition(semantic: Semantic, structureRoot: u64, name: u64): u32 {
    val count = structTypeParameterCount(semantic.nodes.data[structureRoot]);
    for (position in 0..<count) {
        val root = structTypeParameterRoot(semantic, structureRoot, position + 1);
        val parameter = semantic.nodes.data[root];
        if (nodeHash(semantic, semantic.nodes.data[parameter.subtreeStart]) == name) {
            return position;
        }
    }
    return count;
}

fn fieldRootAt(nodes: AstList, structureRoot: u64, wanted: u32): u64 {
    val structure = nodes.data[structureRoot];
    var roots = k_boot_alloc((structFieldCount(structure) as u64) * sizeof(u64)) as u64*;
    var root = rootBeforeStructMethods(nodes, structureRoot);
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
    argumentStart: u64, count: u32
): TypeValue {
    if (type.kind == 14) {
        val position =
            structTypeParameterPosition(semantic, structureRoot, type.name);
        if (position >= count) return invalidType();
        return arguments.data[argumentStart + position as u64];
    }
    if (type.kind == 8) {
        val start = type.pointee % 65536;
        val argCount = type.pointee / 65536;
        if (argCount == 0) return type;
        val newStart = semantic.genericArguments.length;

        for (i in 0..<argCount) {
            val arg = semantic.genericArguments.data[start as u64 + i as u64];
            val substituted = substituteStructType(
                semantic, structureRoot, arg, arguments, argumentStart, count);
            var resolved = semantic.genericArguments;
            resolved.add(substituted);
            semantic.genericArguments = resolved;
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
        for (position in 0..<count) {
            val root = functionTypeParameterRoot(
                semantic, semantic.currentFunction, position + 1);
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
        }
    }
    if (semantic.currentStruct < semantic.nodes.length) {
        val structure =
            semantic.nodes.data[semantic.currentStruct];
        val count = structTypeParameterCount(structure);
        for (position in 0..<count) {
            val root = structTypeParameterRoot(
                semantic, semantic.currentStruct, position + 1);
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
        }
    }
    return invalidType();
}

fn typeParameterPosition(
    semantic: Semantic, functionRoot: u64, name: u64): u32 {
    val count = functionTypeParameterCount(
        semantic.nodes.data[functionRoot]);
    for (position in 0..<count) {
        val root = functionTypeParameterRoot(
            semantic, functionRoot, position + 1);
        val parameter = semantic.nodes.data[root];
        if (nodeHash(
                semantic,
                semantic.nodes.data[parameter.subtreeStart]) == name) {
            return position;
        }
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
        if (inner.kind == 0) return inner;
        return TypeValue(15, inner.name, inner.kind);
    }
    if (type.kind != 14) return type;
    val position =
        typeParameterPosition(semantic, functionRoot, type.name);
    if (position >= count) return invalidType();
    return arguments[position as u64];
}

fn constraintAcceptsType(constraint: u32, type: TypeValue): bool {
    if (constraint == 0) {
        if (type.kind == 0) return false;
        if (type.kind == 1) return false;
        return true;
    }
    if (type.kind == 14) {
        return type.pointee >= constraint;
    }
    if (constraint == 1) {
        if (type.kind == 2) return true;
        if (type.kind >= 3) {
            if (type.kind <= 7) return true;
        }
        return type.kind == 11;
    }
    if (constraint == 2) {
        if (type.kind >= 3) {
            if (type.kind <= 7) return true;
        }
        return type.kind == 11;
    }
    if (constraint == 3) {
        if (type.kind >= 3) {
            if (type.kind <= 7) return true;
        }
        return type.kind == 11;
    }
    if (constraint == 4) {
        if (type.kind >= 3) {
            if (type.kind <= 7) return true;
        }
        return type.kind == 11;
    }
    if (constraint == 5) {
        if (type.kind >= 5) {
            if (type.kind <= 7) return true;
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
        if (primitive.kind != 0) return primitive;
        val parameter = findCurrentTypeParameter(
            semantic, nodeHash(semantic, node));
        if (parameter.kind != 0) return parameter;
        
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
                resolved.add(typeArguments[index as u64]);
                semantic.genericArguments = resolved;
                index = index + 1;
            }
            k_boot_free(typeArguments as unit*);
            return TypeValue(8, nodeHash(semantic, node), start as u32 + typeArgumentCount * 65536);
        }
        
        val name = nodeHash(semantic, node);
        if (declarationFind(semantic.enums, name) != semantic.enums.length) {
            return TypeValue(20, name, 0);
        }
        return TypeValue(8, name, 0);
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
    if (node.kind == 5) {
        var childRoot = root - 1;
        var size: u64 = 0;
        if (node.aux == 1) {
            val constant = integerConstant(semantic, childRoot);
            if (!constant.ok) {
                semanticFail(semantic, 4, semantic.nodes.data[childRoot]);
                return invalidType();
            }
            size = constant.magnitude;
            childRoot = semantic.nodes.data[childRoot].subtreeStart - 1;
        }

        return typeFromNode(semantic, childRoot).array(size);
    }
    if (node.kind == 3) {
        val inner = typeFromNode(semantic, root - 1);
        return TypeValue(15, inner.name, inner.kind);
    }
    return invalidType();
}

fn functionReturnRoot(semantic: Semantic, functionRoot: u64): u64 {
    val function = semantic.nodes.data[functionRoot];
    if (functionIsExtern(function)) return functionRoot - 1;
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

fn functionParameterCount(function: AstNode) => function.aux % 65536;

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
    if (!semantic.result.ok) return invalidType();
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
        val constant = declarationFind(semantic.constants, name);
        if (constant != semantic.constants.length) {
            val declarationRoot = semantic.constants.data[constant].node;
            var resolved = semantic.nodes.data[root];
            resolved.storage = declarationRoot;
            resolved.aux = 1;
            semantic.nodes.data[root] = resolved;
            val declaration = semantic.nodes.data[declarationRoot];
            return TypeValue(declaration.typeKind, declaration.typeName, declaration.typePointee);
        }
        semanticFail(semantic, 2, node);
        return invalidType();
    }
    if (node.kind == 11) {
        if (node.aux == 2) return integerLiteralType();
        if (node.aux == 3) return TypeValue(18, 0, 0);
        if (node.aux == 5) return TypeValue(10, 0, 0);
        if (node.aux == 29) return boolType();
        if (node.aux == 30) return boolType();
        if (node.aux == 31) return TypeValue(16, 0, 0);
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
        if (node.aux == 73) {
            if (operand.kind != 2) {
                semanticFail(semantic, 4, node);
                return invalidType();
            }
            return TypeValue(2, 0, 0);
        }
        return operand;
    }
    if (node.kind == 13) {
        val rightRoot = root - 1;
        val leftRoot = semantic.nodes.data[rightRoot].subtreeStart - 1;
        if (node.aux == 18) {
            val range = semantic.nodes.data[rightRoot];
            var validRange = range.kind == 13;
            if (validRange) {
                validRange = range.aux == 87 || range.aux == 88 ||
                    range.aux == 93 || range.aux == 94;
            }
            if (!validRange) {
                semanticFail(semantic, 4, node);
                return boolType();
            }
            val upperRoot = rightRoot - 1;
            val lowerRoot = semantic.nodes.data[upperRoot].subtreeStart - 1;
            val subject = expressionType(semantic, leftRoot);
            var lower = expressionType(semantic, lowerRoot);
            var upper = expressionType(semantic, upperRoot);
            if (lower.kind == 11) {
                lower = subject;
                var lowerNode = semantic.nodes.data[lowerRoot];
                lowerNode.typeKind = subject.kind;
                semantic.nodes.data[lowerRoot] = lowerNode;
            }
            if (upper.kind == 11) {
                upper = subject;
                var upperNode = semantic.nodes.data[upperRoot];
                upperNode.typeKind = subject.kind;
                semantic.nodes.data[upperRoot] = upperNode;
            }
            if (!subject.isInteger() && !subject.isFloat())
                semanticFail(semantic, 4, node);
            if (!typeAccepts(subject, lower, semantic.genericArguments) ||
                !typeAccepts(subject, upper, semantic.genericArguments))
                semanticFail(semantic, 4, node);
            var typedRange = range;
            typedRange.typeKind = subject.kind;
            typedRange.typeName = subject.name;
            typedRange.typePointee = subject.pointee;
            semantic.nodes.data[rightRoot] = typedRange;
            return boolType();
        }
        val left = expressionType(semantic, leftRoot);
        val right = expressionType(semantic, rightRoot);
        var logical = node.aux == 83;
        if (node.aux == 84) logical = true;
        if (logical) {
            if (left.kind != 2) semanticFail(semantic, 4, node);
            else {
                if (right.kind != 2) semanticFail(semantic, 4, node);
            }
            return boolType();
        }
        var comparison = node.aux == 66;
        if (node.aux == 67) comparison = true;
        if (node.aux >= 79) {
            if (node.aux <= 82) {
                comparison = true;
            }
        }
        if (comparison) {
            if (!typeAccepts(left, right, semantic.genericArguments)) {
                if (!typeAccepts(right, left, semantic.genericArguments)) {
                    semanticFail(semantic, 4, node);
                }
            }
            return boolType();
        }
        if (typeAccepts(left, right, semantic.genericArguments)) return left;
        if (typeAccepts(right, left, semantic.genericArguments)) return right;
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
            if (!semantic.locals.data[local].mutable) {
                semanticFail(semantic, 7, target);
                return invalidType();
            }
        }
        val left = expressionType(semantic, leftRoot);
        val right = expressionType(semantic, rightRoot);
        if (!typeAccepts(left, right, semantic.genericArguments)) {
            semanticFail(semantic, 4, node);
        }
        return left;
    }
    if (node.kind == 15) {
        val typeRoot = root - 1;
        val valueRoot = semantic.nodes.data[typeRoot].subtreeStart - 1;
        var source = expressionType(semantic, valueRoot);
        val target = typeFromNode(semantic, typeRoot);
        if (source.kind == 11) {
            source = TypeValue(3, 0, 0);
            var valueNode = semantic.nodes.data[valueRoot];
            valueNode.typeKind = source.kind;
            semantic.nodes.data[valueRoot] = valueNode;
        }
        var pointerCast = false;
        if (source.kind == 9) {
            if (target.kind == 9) pointerCast = true;
        }
        var integerCast = false;
        if (source.isInteger()) {
            if (target.isInteger()) integerCast = true;
        }
        if (integerCast) {
            val constant = integerConstant(semantic, valueRoot);
            if (constant.ok) {
                if (!integerConstantFits(constant, target)) {
                    semanticFail(semantic, 4, node);
                }
            }
            var castNode = semantic.nodes.data[root];
            castNode.conversionKind = 3;
            if (integerCastRequiresRangeCheck(source, target)) {
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
                        semanticFail(semantic, 4, node);
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
                if (!pointerCast) semanticFail(semantic, 4, node);
            }
        }
        return target;
    }
    if (node.kind == 16) {
        var argumentCount = node.aux % 65536;
        val explicitTypeCount = node.aux / 65536;
        val argumentRoots =
            k_boot_alloc(
                ((argumentCount + 1) as u64) * sizeof(u64)) as u64*;
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
        var functionName: u64 = 0;
        if (callee.kind == 10) {
            functionName = nodeHash(semantic, callee);
        } else {
            if (callee.kind == 17 && explicitTypeCount == 0) {
                val objectRoot = cursor - 1;
                val object = expressionType(semantic, objectRoot);
                if (object.kind == 8) {
                    argument = argumentCount;
                    while (argument > 0) {
                        argumentRoots[argument as u64] =
                            argumentRoots[argument as u64 - 1];
                        argument = argument - 1;
                    }
                    argumentRoots[0] = objectRoot;
                    argumentCount = argumentCount + 1;
                    functionName = methodHash(object.name, nodeHash(semantic, callee));
                }
            }
        }
        if (functionName == 0) {
            semanticFail(semantic, 2, callee);
            k_boot_free(explicitTypeRoots as unit*);
            k_boot_free(argumentRoots as unit*);
            return invalidType();
        }
        val functionIndex = declarationFind(
            semantic.functions, functionName);
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
                            if (
                                !typeEquals(
                                    typeArguments[position as u64],
                                    inferredActual, semantic.genericArguments
                                )
                            ) {
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
                if (!typeAccepts(expected, actual, semantic.genericArguments)) {
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

                if (
                    !constraintAcceptsType(
                        constraint,
                        typeArguments[explicit as u64]
                    )
                ) semanticFail(semantic, 4, callee);

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
                    resolved.add(typeArguments[typeIndex as u64]);
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
        var resolvedCall = semantic.nodes.data[root];
        resolvedCall.storage = functionRoot;
        semantic.nodes.data[root] = resolvedCall;
        if (function.conversionKind == 1) {
            val receiverParameter = semantic.nodes.data[
                functionParameterRoot(semantic, functionRoot, 1)];
            if (receiverParameter.aux == 2) {
                val receiverNode = semantic.nodes.data[argumentRoots[0]];
                if (receiverNode.kind == 10) {
                    val receiverLocal = localFind(
                        semantic.locals, nodeHash(semantic, receiverNode));
                    if (receiverLocal == semantic.locals.length) {
                        semanticFail(semantic, 7, receiverNode);
                    } else {
                        if (!semantic.locals.data[receiverLocal].mutable)
                            semanticFail(semantic, 7, receiverNode);
                    }
                }
            }
        }
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
                        if (
                            !typeEquals(
                                typeArguments[position as u64],
                                inferredActual, semantic.genericArguments
                            )
                        ) {
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
            if (!typeAccepts(expected, actual, semantic.genericArguments)) {
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

            if (
                !constraintAcceptsType(
                    constraint,
                    typeArguments[explicit as u64]
                )
            ) semanticFail(semantic, 4, callee);

            explicit = explicit + 1;
        }
        val savedFunction = semantic.currentFunction;
        semantic.currentFunction = functionRoot;
        val returnPattern = functionReturnTypeValue(semantic, functionRoot);
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
                resolved.add(typeArguments[typeIndex as u64]);
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
        val objectNode = semantic.nodes.data[objectRoot];
        if (objectNode.kind == 10) {
            val enumIndex = declarationFind(
                semantic.enums, nodeHash(semantic, objectNode));
            if (enumIndex != semantic.enums.length) {
                val enumRoot = semantic.enums.data[enumIndex].node;
                val enumeration = semantic.nodes.data[enumRoot];
                val wanted = nodeHash(semantic, node);
                var position: u32 = 0;
                while (position < enumeration.aux) {
                    val variant = semantic.nodes.data[
                        enumeration.subtreeStart + 1 + position as u64];
                    if (nodeHash(semantic, variant) == wanted) {
                        var resolvedObject = objectNode;
                        resolvedObject.typeKind = 20;
                        resolvedObject.typeName = semantic.enums.data[enumIndex].name;
                        semantic.nodes.data[objectRoot] = resolvedObject;
                        var resolved = node;
                        resolved.storage = position as u64;
                        resolved.typeKind = 20;
                        resolved.typeName = semantic.enums.data[enumIndex].name;
                        semantic.nodes.data[root] = resolved;
                        return TypeValue(20, resolved.typeName, 0);
                    }
                    position = position + 1;
                }
                semanticFail(semantic, 2, node);
                return invalidType();
            }
        }
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
        var cursor = rootBeforeStructMethods(semantic.nodes, structureRoot);
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
        if (object.kind == 19) {
            return object.arrayElement();
        }
        if (object.kind == 13) {
            return TypeValue(object.pointee, object.name, 0);
        }
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
        if (node.aux == 91 || node.aux == 92) {
            if (semantic.mutationRoot != root) semanticFail(semantic, 4, node);
            if (!operand.isFloat() && !operand.isInteger())
                semanticFail(semantic, 4, node);
            val target = semantic.nodes.data[root - 1];
            if (target.kind == 10) {
                val local = localFind(semantic.locals, nodeHash(semantic, target));
                if (local == semantic.locals.length) semanticFail(semantic, 2, target);
                else {
                    if (!semantic.locals.data[local].mutable)
                        semanticFail(semantic, 7, target);
                }
            }
            return operand;
        }
        if (operand.kind != 15) {
            semanticFail(semantic, 4, node);
            return invalidType();
        }
        return TypeValue(operand.pointee, operand.name, 0);
    }
    if (node.kind == 25) {
        val thenCount = node.aux % 65536;
        val elseCount = node.aux / 65536;
        val elseValueRoot = root - 1;
        val elseRoots =
            k_boot_alloc((elseCount as u64) * sizeof(u64)) as u64*;
        var childRoot = semantic.nodes.data[elseValueRoot].subtreeStart - 1;
        var remaining = elseCount;
        while (remaining > 0) {
            elseRoots[remaining as u64 - 1] = childRoot;
            childRoot = semantic.nodes.data[childRoot].subtreeStart - 1;
            remaining = remaining - 1;
        }
        val thenValueRoot = childRoot;
        val thenRoots =
            k_boot_alloc((thenCount as u64) * sizeof(u64)) as u64*;
        childRoot = semantic.nodes.data[thenValueRoot].subtreeStart - 1;
        remaining = thenCount;
        while (remaining > 0) {
            thenRoots[remaining as u64 - 1] = childRoot;
            childRoot = semantic.nodes.data[childRoot].subtreeStart - 1;
            remaining = remaining - 1;
        }
        val condition = expressionType(semantic, childRoot);
        if (condition.kind != 2) {
            semanticFail(semantic, 6, semantic.nodes.data[childRoot]);
        }
        val savedLocals = semantic.locals.length;
        val savedScopeStart = semantic.scopeStart;
        semantic.scopeStart = savedLocals;
        var index: u32 = 0;
        while (index < thenCount) {
            checkStatement(semantic, thenRoots[index as u64]);
            index = index + 1;
        }
        val thenType = expressionType(semantic, thenValueRoot);
        var restoredLocals = semantic.locals;
        restoredLocals.length = savedLocals;
        semantic.locals = restoredLocals;
        semantic.scopeStart = savedLocals;
        index = 0;
        while (index < elseCount) {
            checkStatement(semantic, elseRoots[index as u64]);
            index = index + 1;
        }
        val elseType = expressionType(semantic, elseValueRoot);
        restoredLocals = semantic.locals;
        restoredLocals.length = savedLocals;
        semantic.locals = restoredLocals;
        semantic.scopeStart = savedScopeStart;
        k_boot_free(thenRoots as unit*);
        k_boot_free(elseRoots as unit*);
        if (!typeAccepts(thenType, elseType, semantic.genericArguments)) {
            semanticFail(semantic, 4, semantic.nodes.data[elseValueRoot]);
        }
        var resolved = semantic.nodes.data[root];
        resolved.typeKind = thenType.kind;
        resolved.typeName = thenType.name;
        resolved.typePointee = thenType.pointee;
        semantic.nodes.data[root] = resolved;
        return thenType;
    }
    if (node.kind == 23) {
        val branchCount = node.aux % 65536;
        val hasSubject = node.aux / 65536;
        val roots = k_boot_alloc((branchCount as u64) * sizeof(u64)) as u64*;
        var branchRoot = root - 1;
        var remaining = branchCount;
        while (remaining > 0) {
            roots[remaining as u64 - 1] = branchRoot;
            branchRoot = semantic.nodes.data[branchRoot].subtreeStart - 1;
            remaining = remaining - 1;
        }
        var subject = invalidType();
        if (hasSubject == 1) {
            subject = expressionType(semantic, branchRoot);
            if (subject.kind == 11) {
                subject = TypeValue(3, 0, 0);
                var subjectNode = semantic.nodes.data[branchRoot];
                subjectNode.typeKind = 3;
                semantic.nodes.data[branchRoot] = subjectNode;
            }
        }
        var result = invalidType();
        var hasElse = false;
        var index: u32 = 0;
        while (index < branchCount) {
            val branch = semantic.nodes.data[roots[index as u64]];
            if (branch.aux % 2 == 1) hasElse = true;
            val valueRoot = roots[index as u64] - 1;
            val statementCount = (branch.aux % 65536) / 2;
            val statementRoots =
                k_boot_alloc((statementCount as u64) * sizeof(u64)) as u64*;
            var beforeValue = semantic.nodes.data[valueRoot].subtreeStart - 1;
            var statementRemaining = statementCount;
            while (statementRemaining > 0) {
                statementRoots[statementRemaining as u64 - 1] = beforeValue;
                beforeValue = semantic.nodes.data[beforeValue].subtreeStart - 1;
                statementRemaining = statementRemaining - 1;
            }
            if (branch.aux % 2 == 0) {
              var patternIndex: u32 = 0;
              val patternCount = branch.aux / 65536;
              while (patternIndex < patternCount) {
                val conditionRoot = whenPatternRoot(
                    semantic, roots[index as u64], true, patternIndex);
                val condition = expressionType(semantic, conditionRoot);
                if (hasSubject == 1) {
                    if (!typeAccepts(subject, condition, semantic.genericArguments)) {
                        semanticFail(semantic, 4, semantic.nodes.data[conditionRoot]);
                    } else {
                        var conditionNode = semantic.nodes.data[conditionRoot];
                        conditionNode.typeKind = subject.kind;
                        conditionNode.typeName = subject.name;
                        conditionNode.typePointee = subject.pointee;
                        semantic.nodes.data[conditionRoot] = conditionNode;
                    }
                } else {
                    if (condition.kind != 2) {
                        semanticFail(semantic, 6, semantic.nodes.data[conditionRoot]);
                    }
                }
                patternIndex = patternIndex + 1;
              }
            }
            val savedLocals = semantic.locals.length;
            val savedScopeStart = semantic.scopeStart;
            semantic.scopeStart = savedLocals;
            var statementIndex: u32 = 0;
            while (statementIndex < statementCount) {
                checkStatement(semantic, statementRoots[statementIndex as u64]);
                statementIndex = statementIndex + 1;
            }
            var value = expressionType(semantic, valueRoot);
            var restoredLocals = semantic.locals;
            restoredLocals.length = savedLocals;
            semantic.locals = restoredLocals;
            semantic.scopeStart = savedScopeStart;
            k_boot_free(statementRoots as unit*);
            if (result.kind == 0) {
                result = value;
            } else {
                if (!typeAccepts(result, value, semantic.genericArguments)) {
                    semanticFail(semantic, 4, semantic.nodes.data[valueRoot]);
                } else {
                    var valueNode = semantic.nodes.data[valueRoot];
                    valueNode.typeKind = result.kind;
                    valueNode.typeName = result.name;
                    valueNode.typePointee = result.pointee;
                    semantic.nodes.data[valueRoot] = valueNode;
                }
            }
            index = index + 1;
        }
        val exhaustive = enumWhenExhaustive(
            semantic, subject, roots, branchCount, true);
        if (!hasElse && !exhaustive) {
            semanticFail(semantic, 4, node);
        }
        var resolved = semantic.nodes.data[root];
        resolved.typeKind = result.kind;
        resolved.typeName = result.name;
        resolved.typePointee = result.pointee;
        semantic.nodes.data[root] = resolved;
        k_boot_free(roots as unit*);
        return result;
    }
    if (node.kind == 22) {
        if (node.aux == 0) return invalidType().array(0);
        var childRoot = root - 1;
        var element = expressionType(semantic, childRoot);
        if (element.kind == 11) element = TypeValue(3, 0, 0);
        var remaining = node.aux;
        while (remaining > 0) {
            val actual = expressionType(semantic, childRoot);
            if (!typeAccepts(element, actual, semantic.genericArguments)) {
                semanticFail(semantic, 4, semantic.nodes.data[childRoot]);
                return invalidType();
            }
            var childNode = semantic.nodes.data[childRoot];
            childNode.typeKind = element.kind;
            childNode.typeName = element.name;
            childNode.typePointee = element.pointee;
            semantic.nodes.data[childRoot] = childNode;
            childRoot = childNode.subtreeStart - 1;
            remaining = remaining - 1;
        }
        return element.array(node.aux as u64);
    }
    if (node.kind == 20) return unitType();
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

fn resolveWhenResultType(
    var semantic: Semantic, root: u64, target: TypeValue) {
    var whenNode = semantic.nodes.data[root];
    if (whenNode.kind != 23) return;
    whenNode.typeKind = target.kind;
    whenNode.typeName = target.name;
    whenNode.typePointee = target.pointee;
    semantic.nodes.data[root] = whenNode;
    val branchCount = whenNode.aux % 65536;
    var branchRoot = root - 1;
    var remaining = branchCount;
    while (remaining > 0) {
        val valueRoot = branchRoot - 1;
        var valueNode = semantic.nodes.data[valueRoot];
        if (valueNode.typeKind == 11) {
            valueNode.typeKind = target.kind;
            valueNode.typeName = target.name;
            valueNode.typePointee = target.pointee;
            semantic.nodes.data[valueRoot] = valueNode;
        }
        branchRoot = semantic.nodes.data[branchRoot].subtreeStart - 1;
        remaining = remaining - 1;
    }
}

fn resolveIfResultType(
    var semantic: Semantic, root: u64, target: TypeValue) {
    var ifNode = semantic.nodes.data[root];
    if (ifNode.kind != 25) return;
    ifNode.typeKind = target.kind;
    ifNode.typeName = target.name;
    ifNode.typePointee = target.pointee;
    semantic.nodes.data[root] = ifNode;
    val elseValueRoot = root - 1;
    var thenValueRoot = semantic.nodes.data[elseValueRoot].subtreeStart - 1;
    var remaining = ifNode.aux / 65536;
    while (remaining > 0) {
        thenValueRoot = semantic.nodes.data[thenValueRoot].subtreeStart - 1;
        remaining = remaining - 1;
    }
    var valueNode = semantic.nodes.data[thenValueRoot];
    if (valueNode.typeKind == 11) {
        valueNode.typeKind = target.kind;
        valueNode.typeName = target.name;
        valueNode.typePointee = target.pointee;
        semantic.nodes.data[thenValueRoot] = valueNode;
    }
    valueNode = semantic.nodes.data[elseValueRoot];
    if (valueNode.typeKind == 11) {
        valueNode.typeKind = target.kind;
        valueNode.typeName = target.name;
        valueNode.typePointee = target.pointee;
        semantic.nodes.data[elseValueRoot] = valueNode;
    }
}

fn checkStatement(var semantic: Semantic, root: u64) {
    if (!semantic.result.ok) return;
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
        semantic.loopDepth = semantic.loopDepth + 1;
        checkBlock(semantic, bodyRoot);
        semantic.loopDepth = semantic.loopDepth - 1;
        val conditionRoot =
            semantic.nodes.data[bodyRoot].subtreeStart - 1;
        if (expressionType(semantic, conditionRoot).kind != 2) {
            semanticFail(
                semantic, 6, semantic.nodes.data[conditionRoot]);
        }
        return;
    }
    if (node.kind == 38) {
        val bodyRoot = root - 1;
        val collectionRoot =
            semantic.nodes.data[bodyRoot].subtreeStart - 1;
        var collectionNode = semantic.nodes.data[collectionRoot];
        var valueType = expressionType(semantic, collectionRoot);
        var range = collectionNode.kind == 13;
        if (range) {
            range = collectionNode.aux == 87;
            if (collectionNode.aux == 88) range = true;
            if (collectionNode.aux == 93) range = true;
            if (collectionNode.aux == 94) range = true;
        }
        if (range) {
            if (node.aux == 1) {
                semanticFail(
                    semantic, 4,
                    semantic.nodes.data[node.subtreeStart + 1]);
                return;
            }
        } else {
            var collection = valueType.kind == 13;
            if (valueType.kind == 19) collection = true;
            if (!collection) {
                semanticFail(semantic, 4, collectionNode);
                return;
            }
            if (valueType.kind == 13) {
                valueType = TypeValue(
                    valueType.pointee, valueType.name, 0);
            } else {
                valueType = valueType.arrayElement();
            }
        }
        if (valueType.kind == 11) {
            valueType = TypeValue(3, 0, 0);
            collectionNode.typeKind = 3;
            semantic.nodes.data[collectionRoot] = collectionNode;
            val rightRoot = collectionRoot - 1;
            val leftRoot =
                semantic.nodes.data[rightRoot].subtreeStart - 1;
            var rightNode = semantic.nodes.data[rightRoot];
            var leftNode = semantic.nodes.data[leftRoot];
            rightNode.typeKind = 3;
            leftNode.typeKind = 3;
            semantic.nodes.data[rightRoot] = rightNode;
            semantic.nodes.data[leftRoot] = leftNode;
        }
        if (range) {
            if (!valueType.isInteger()) {
                semanticFail(semantic, 4, collectionNode);
                return;
            }
        }
        val savedLocals = semantic.locals.length;
        val nameNode = semantic.nodes.data[node.subtreeStart];
        var locals = semantic.locals;
        localListAppend(
            locals, LocalInfo(
                nodeHash(semantic, nameNode), valueType, false, nameNode.start));
        if (node.aux == 1) {
            val indexNode = semantic.nodes.data[node.subtreeStart + 1];
            localListAppend(
                locals, LocalInfo(
                    nodeHash(semantic, indexNode),
                    TypeValue(7, 0, 0), false, indexNode.start));
        }
        semantic.locals = locals;
        semantic.loopDepth = semantic.loopDepth + 1;
        checkBlock(semantic, bodyRoot);
        semantic.loopDepth = semantic.loopDepth - 1;
        var restored = semantic.locals;
        restored.length = savedLocals;
        semantic.locals = restored;
        return;
    }
    if (node.kind == 39) {
        val branchCount = node.aux % 65536;
        val hasSubject = node.aux / 65536;
        if (branchCount == 0) {
            semanticFail(semantic, 4, node);
            return;
        }
        val roots =
            k_boot_alloc((branchCount as u64) * sizeof(u64)) as u64*;
        var branchRoot = root - 1;
        var remaining = branchCount;
        while (remaining > 0) {
            roots[remaining as u64 - 1] = branchRoot;
            branchRoot = semantic.nodes.data[branchRoot].subtreeStart - 1;
            remaining = remaining - 1;
        }
        var subject = invalidType();
        if (hasSubject == 1) {
            val subjectRoot = branchRoot;
            subject = expressionType(semantic, subjectRoot);
            if (subject.kind == 11) {
                subject = TypeValue(3, 0, 0);
                var subjectNode = semantic.nodes.data[subjectRoot];
                subjectNode.typeKind = 3;
                semantic.nodes.data[subjectRoot] = subjectNode;
            }
            var comparable = subject.kind == 2;
            if (subject.isInteger()) comparable = true;
            if (subject.kind == 20) comparable = true;
            if (!comparable) {
                semanticFail(semantic, 6, semantic.nodes.data[subjectRoot]);
            }
        }
        var index: u32 = 0;
        var hasElse = false;
        while (index < branchCount) {
            val current = semantic.nodes.data[roots[index as u64]];
            if (current.aux % 2 == 1) hasElse = true;
            val bodyRoot = roots[index as u64] - 1;
            if (current.aux % 2 == 0) {
              var patternIndex: u32 = 0;
              val patternCount = current.aux / 65536;
              while (patternIndex < patternCount) {
                val conditionRoot = whenPatternRoot(
                    semantic, roots[index as u64], false, patternIndex);
                val condition = expressionType(semantic, conditionRoot);
                if (hasSubject == 1) {
                    if (
                        !typeAccepts(
                            subject, condition,
                            semantic.genericArguments
                        )
                    ) {
                        semanticFail(
                            semantic, 4,
                            semantic.nodes.data[conditionRoot]);
                    } else {
                        var conditionNode = semantic.nodes.data[conditionRoot];
                        conditionNode.typeKind = subject.kind;
                        conditionNode.typeName = subject.name;
                        conditionNode.typePointee = subject.pointee;
                        semantic.nodes.data[conditionRoot] = conditionNode;
                    }
                } else {
                    if (condition.kind != 2) {
                        semanticFail(
                            semantic, 6,
                            semantic.nodes.data[conditionRoot]);
                    }
                }
                patternIndex = patternIndex + 1;
              }
            }
            checkBlock(semantic, bodyRoot);
            index = index + 1;
        }
        val exhaustive = enumWhenExhaustive(
            semantic, subject, roots, branchCount, false);
        if (subject.kind == 20 && !hasElse && !exhaustive) {
            semanticFail(semantic, 4, node);
        }
        k_boot_free(roots as unit*);
        return;
    }
    if (node.kind == 36) {
        if (semantic.loopDepth == 0) {
            semanticFail(semantic, 4, node);
        }
        return;
    }
    if (node.kind == 37) {
        if (semantic.loopDepth == 0) {
            semanticFail(semantic, 4, node);
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
        if (valueType.kind == 11) {
            valueType = TypeValue(3, 0, 0);
            var initializerNode = semantic.nodes.data[initializerRoot];
            initializerNode.typeKind = 3;
            semantic.nodes.data[initializerRoot] = initializerNode;
            resolveWhenResultType(semantic, initializerRoot, valueType);
            resolveIfResultType(semantic, initializerRoot, valueType);
        }
        val afterName = node.subtreeStart + 1;
        if (afterName < semantic.nodes.data[initializerRoot].subtreeStart) {
            valueType = typeFromNode(
                semantic,
                semantic.nodes.data[initializerRoot].subtreeStart - 1);
            if (!typeAccepts(valueType, initializer, semantic.genericArguments)) {
                semanticFail(
                    semantic, 4, semantic.nodes.data[initializerRoot]);
            }
            resolveWhenResultType(semantic, initializerRoot, valueType);
            resolveIfResultType(semantic, initializerRoot, valueType);
            if (initializer.kind == 19) {
                if (initializer.arrayElement().kind == 0) {
                    var initializerNode = semantic.nodes.data[initializerRoot];
                    initializerNode.typeKind = valueType.kind;
                    initializerNode.typeName = valueType.name;
                    initializerNode.typePointee = valueType.pointee;
                    semantic.nodes.data[initializerRoot] = initializerNode;
                }
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
        val function = semantic.nodes.data[semantic.currentFunction];
        if (function.storage % 2 == 1 && node.aux == 1) {
            var statementLike = actual.kind == 1;
            if (semantic.nodes.data[root - 1].kind == 14) statementLike = true;
            if (statementLike) {
                if (semantic.returnType.kind != 1)
                    semanticFail(semantic, 5, semantic.nodes.data[root - 1]);
                else {
                    var expressionStatement = node;
                    expressionStatement.kind = 35;
                    semantic.nodes.data[root] = expressionStatement;
                }
                return;
            }
        }
        if (!typeAccepts(semantic.returnType, actual, semantic.genericArguments)) {
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
                resolveWhenResultType(
                    semantic, root - 1, semantic.returnType);
                resolveIfResultType(
                    semantic, root - 1, semantic.returnType);
            }
        }
        return;
    }
    if (node.kind == 35) {
        val previousMutationRoot = semantic.mutationRoot;
        semantic.mutationRoot = root - 1;
        expressionType(semantic, root - 1);
        semantic.mutationRoot = previousMutationRoot;
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
    semantic.returnType = functionReturnTypeValue(semantic, root);
    var position: u32 = 0;
    val count = functionParameterCount(function);
    while (position < count) {
        val parameterRoot =
            functionParameterRoot(semantic, root, position + 1);
        val parameter = semantic.nodes.data[parameterRoot];
        val nameNode = semantic.nodes.data[parameter.subtreeStart];
        val mutable = parameter.aux != 1;
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

fn isConstantExpression(semantic: Semantic, root: u64): bool {
    val node = semantic.nodes.data[root];
    if (node.kind == 11) return true;
    if (node.kind == 10) {
        return declarationFind(
            semantic.constants, nodeHash(semantic, node)) !=
            semantic.constants.length;
    }
    if (node.kind == 12) return isConstantExpression(semantic, root - 1);
    if (node.kind == 13) {
        val rightRoot = root - 1;
        val leftRoot = semantic.nodes.data[rightRoot].subtreeStart - 1;
        return isConstantExpression(semantic, leftRoot) &&
            isConstantExpression(semantic, rightRoot);
    }
    if (node.kind == 15) {
        val typeRoot = root - 1;
        return isConstantExpression(
            semantic, semantic.nodes.data[typeRoot].subtreeStart - 1);
    }
    if (node.kind == 22) {
        var childRoot = root - 1;
        var remaining = node.aux;
        while (remaining > 0) {
            if (!isConstantExpression(semantic, childRoot)) return false;
            childRoot = semantic.nodes.data[childRoot].subtreeStart - 1;
            remaining = remaining - 1;
        }
        return true;
    }
    return false;
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
        if (declaration.kind == 43) {
            val nameNode = semantic.nodes.data[declaration.subtreeStart];
            val name = nodeHash(semantic, nameNode);
            if (declarationFind(semantic.structs, name) !=
                    semantic.structs.length) {
                semanticFail(semantic, 1, nameNode);
            } else {
                var structures = semantic.structs;
                declarationListAppend(
                    structures, DeclarationInfo(name, root));
                semantic.structs = structures;
            }
            var methodRoot = root - 1;
            var methods = structMethodCount(declaration);
            while (methods > 0) {
                val method = semantic.nodes.data[methodRoot];
                val methodNameNode = semantic.nodes.data[method.subtreeStart];
                val methodName = methodHash(name, nodeHash(semantic, methodNameNode));
                if (structTypeParameterCount(declaration) != 0 ||
                    functionTypeParameterCount(method) != 0 ||
                    functionParameterCount(method) == 0) {
                    semanticFail(semantic, 4, methodNameNode);
                } else {
                    val receiverRoot = functionParameterRoot(semantic, methodRoot, 1);
                    val receiver = semantic.nodes.data[receiverRoot];
                    val receiverName = semantic.nodes.data[receiver.subtreeStart];
                    if (nodeHash(semantic, receiverName) != 6385687311 ||
                        receiver.aux == 0) {
                        semanticFail(semantic, 4, receiverName);
                    } else {
                        var functions = semantic.functions;
                        declarationListAppend(
                            functions, DeclarationInfo(methodName, methodRoot));
                        semantic.functions = functions;
                    }
                }
                methodRoot = method.subtreeStart - 1;
                methods = methods - 1;
            }
            var fieldRoot = rootBeforeStructMethods(semantic.nodes, root);
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
            if (declaration.kind == 50) {
                val nameNode = semantic.nodes.data[declaration.subtreeStart];
                val name = nodeHash(semantic, nameNode);
                val initializerRoot = root - 1;
                var actual = expressionType(semantic, initializerRoot);
                if (declaration.aux == 0) {
                    if (actual.kind == 19) {
                        if (actual.arrayElement().kind == 0)
                            semanticFail(semantic, 4, semantic.nodes.data[initializerRoot]);
                    }
                }
                if (!isConstantExpression(semantic, initializerRoot))
                    semanticFail(semantic, 4, semantic.nodes.data[initializerRoot]);
                if (declaration.aux == 1) {
                    val expected = typeFromNode(
                        semantic, semantic.nodes.data[initializerRoot].subtreeStart - 1);
                    val typeNode = semantic.nodes.data[
                        semantic.nodes.data[initializerRoot].subtreeStart - 1];
                    var accepted = typeAccepts(
                        expected, actual, semantic.genericArguments);
                    if (expected.kind == 19 && typeNode.kind == 5 &&
                        typeNode.aux == 0 && actual.kind == 19) {
                        accepted = typeAccepts(
                            expected.arrayElement(), actual.arrayElement(),
                            semantic.genericArguments);
                    }
                    if (!accepted)
                        semanticFail(semantic, 4, semantic.nodes.data[initializerRoot]);
                    if (expected.kind == 19 && typeNode.kind == 5 &&
                        typeNode.aux == 0 && actual.kind == 19) {
                        actual = expected.arrayElement().array(actual.arraySize());
                    } else actual = expected;
                }
                var typed = declaration;
                typed.typeKind = actual.kind;
                typed.typeName = actual.name;
                typed.typePointee = actual.pointee;
                semantic.nodes.data[root] = typed;
                var constants = semantic.constants;
                declarationListAppend(constants, DeclarationInfo(name, root));
                semantic.constants = constants;
            } else {
            if (declaration.kind == 49) {
                val nameNode = semantic.nodes.data[declaration.subtreeStart];
                val name = nodeHash(semantic, nameNode);
                if (declarationFind(semantic.enums, name) != semantic.enums.length) {
                    semanticFail(semantic, 1, nameNode);
                } else {
                    var enums = semantic.enums;
                    declarationListAppend(enums, DeclarationInfo(name, root));
                    semantic.enums = enums;
                }
                var left: u32 = 0;
                while (left < declaration.aux) {
                    var right = left + 1;
                    while (right < declaration.aux) {
                        val leftNode = semantic.nodes.data[
                            declaration.subtreeStart + 1 + left as u64];
                        val rightNode = semantic.nodes.data[
                            declaration.subtreeStart + 1 + right as u64];
                        if (nodeHash(semantic, leftNode) == nodeHash(semantic, rightNode)) {
                            semanticFail(semantic, 1, rightNode);
                        }
                        right = right + 1;
                    }
                    left = left + 1;
                }
            } else {
            if (declaration.kind == 41) {
                val nameNode = semantic.nodes.data[declaration.subtreeStart];
                val name = nodeHash(semantic, nameNode);
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
            }
            }
        }
        index = index + 1;
    }
    k_boot_free(roots as unit*);
}

fn analyze(source: Source, nodes: AstList): SemanticResult {
    val genericArguments = typeValueListNew();
    var semantic = Semantic(
        source, nodes, declarationListNew(), declarationListNew(), declarationListNew(),
        declarationListNew(),
        localListNew(), genericArguments,
        semanticSuccess(genericArguments), unitType(), 0,
        nodes.length, nodes.length, 0, nodes.length
    );
    val programRoot = nodes.length - 1;
    collectDeclarations(semantic, programRoot);
    if (semantic.result.ok) {
        val program = nodes.data[programRoot];
        var root = programRoot - 1;
        var remaining = program.aux;
        while (remaining > 0) {
            if (nodes.data[root].kind == 41) {
                checkFunction(semantic, root);
            } else {
                if (nodes.data[root].kind == 43) {
                    var methodRoot = root - 1;
                    var methods = structMethodCount(nodes.data[root]);
                    while (methods > 0) {
                        checkFunction(semantic, methodRoot);
                        methodRoot = nodes.data[methodRoot].subtreeStart - 1;
                        methods = methods - 1;
                    }
                }
            }
            root = nodes.data[root].subtreeStart - 1;
            remaining = remaining - 1;
        }
    }
    var result = semantic.result;
    result.genericArguments = semantic.genericArguments;
    localListFree(semantic.locals);
    declarationListFree(semantic.functions);
    declarationListFree(semantic.constants);
    declarationListFree(semantic.enums);
    declarationListFree(semantic.structs);
    return result;
}
