module bootstrap.semantic;

import bootstrap.*;
import bootstrap.token.TokenKind;

struct Semantic(
    source: Source,
    nodes: List<AstNode>,
    structs: List<DeclarationInfo>,
    enums: List<DeclarationInfo>,
    functions: List<DeclarationInfo>,
    constants: List<DeclarationInfo>,
    locals: List<LocalInfo>,
    genericArguments: List<TypeValue>,
    result: SemanticResult,
    returnType: TypeValue,
    scopeStart: u64,
    currentFunction: u64,
    currentStruct: u64,
    loopDepth: u32,
    mutationRoot: u64,
    suppressMoves: bool
) {

	fn free(var self) {
		k_boot_free(self.locals.data as unit*);
		k_boot_free(self.functions.data as unit*);
		k_boot_free(self.constants.data as unit*);
		k_boot_free(self.enums.data as unit*);
		k_boot_free(self.structs.data as unit*);
	}
}

struct IntegerConstant(ok: bool, negative: bool, overflow: bool, magnitude: u64)

fn sourceHash(source: Source, start: u64, end: u64): u64 {
    var value: u64 = 5381;
    for (i in start..<end) value = value * 33 + source.data[i] as u64;
    return value;
}

fn nodeHash(val semantic: Semantic, node: AstNode) =>
    sourceHash(semantic.source, node.start, node.end);

fn enumVariantStart(enumeration: AstNode) =>
    enumeration.subtreeStart + 1 + enumeration.storage;

fn enumExplicitConstant(val semantic: Semantic, variant: AstNode): IntegerConstant {
    if (variant.conversionKind == 0)
        return IntegerConstant(false, false, false, 0);
    var magnitude: u64 = 0;
    var overflow = false;
    for (offset in variant.storage..<variant.typeName) {
        val digit = (semantic.source.data[offset] - 48) as u64;
        if (magnitude > 1844674407370955161) overflow = true;
        else if (magnitude == 1844674407370955161 && digit > 5) overflow = true;
        if (!overflow) magnitude = magnitude * 10 + digit;
    }
    return IntegerConstant(true, variant.ownership == 1, overflow, magnitude);
}

fn integerConstant(val semantic: Semantic, root: u64): IntegerConstant {
    var node = semantic.nodes.data[root];
    var negative = false;
    if (node.kind == AstKind.Unary) {
        if (node.aux != TokenKind.Plus.value) {
            if (node.aux != TokenKind.Minus.value) {
                return IntegerConstant(false, false, false, 0);
            }
        }
        negative = node.aux == TokenKind.Minus.value;
        node = semantic.nodes.data[root - 1];
    }
    if (node.kind != AstKind.Literal) return IntegerConstant(false, false, false, 0);
    if (node.aux != TokenKind.IntegerLiteral.value)
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
    if (node.kind == AstKind.Unary) {
        if (node.aux != TokenKind.Plus.value) {
            if (node.aux != TokenKind.Minus.value) {
                return IntegerConstant(false, false, false, 0);
            }
        }
        negative = node.aux == TokenKind.Minus.value;
        node = semantic.nodes.data[root - 1];
    }
    if (node.kind != AstKind.Literal) {
        return IntegerConstant(false, false, false, 0);
    }
    if (node.aux != TokenKind.FloatLiteral.value)
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

fn nodeIsPrint(val semantic: Semantic, node: AstNode): bool {
    if (node.end - node.start != 5) return false;
    if (semantic.source.data[node.start] != 112) return false;
    if (semantic.source.data[node.start + 1] != 114) return false;
    if (semantic.source.data[node.start + 2] != 105) return false;
    if (semantic.source.data[node.start + 3] != 110) return false;
    return semantic.source.data[node.start + 4] == 116;
}

fn semanticFail(var semantic: Semantic, category: u32, node: AstNode) =>
    if (semantic.result.ok) 
        semantic.result = semanticError(category, node, semantic.genericArguments);

fn whenConditionRoot(val semantic: Semantic, branchRoot: u64, valueForm: bool): u64 {
    if (!valueForm) {
        val bodyRoot = branchRoot - 1;
        return semantic.nodes.data[bodyRoot].subtreeStart - 1;
    }
    val branch = semantic.nodes.data[branchRoot];
    val valueRoot = branchRoot - 1;
    var conditionRoot = semantic.nodes.data[valueRoot].subtreeStart - 1;
    val statements = (branch.aux % 65536) / 2;
    for (statement in 0..<statements) {
        conditionRoot = semantic.nodes.data[conditionRoot].subtreeStart - 1;
    }
    return conditionRoot;
}

fn whenPatternRoot(
    val semantic: Semantic, branchRoot: u64,
    valueForm: bool, patternIndex: u32
): u64 {
    val branch = semantic.nodes.data[branchRoot];
    val patternCount = branch.aux / 65536;
    var root = whenConditionRoot(semantic, branchRoot, valueForm);
    val remaining = patternCount - patternIndex - 1;
    for (index in 0..<remaining) {
        root = semantic.nodes.data[root].subtreeStart - 1;
    }
    return root;
}

fn enumWhenExhaustive(
    var semantic: Semantic, subject: TypeValue, 
    roots: u64*, branchCount: u32, valueForm: bool
): bool {
    if (subject.kind != TypeKind.Enum) return false;
    val enumIndex = declarationFind(semantic.enums, subject.name);
    if (enumIndex == semantic.enums.length) return false;
    val declaration = semantic.nodes.data[semantic.enums.data[enumIndex].node];
    var unique: u32 = 0;
    for (index in 0..<branchCount) {
        val branch = semantic.nodes.data[roots[index as u64]];
        val isElse = branch.aux % 2 == 1;

        if (!isElse) {
          val patternCount = branch.aux / 65536;
          for (patternIndex in 0..<patternCount) {
            val conditionRoot = whenPatternRoot(
                semantic, roots[index as u64], valueForm, patternIndex);
            val condition = semantic.nodes.data[conditionRoot];
            if (condition.kind == AstKind.Member && condition.typeKind == TypeKind.Enum.value &&
                    condition.typeName == subject.name) {
                for (prior in 0..index) {
                    val priorBranch = semantic.nodes.data[roots[prior as u64]];
                    val priorElse = priorBranch.aux % 2 == 1;
                    if (!priorElse) {
                      var priorCount = priorBranch.aux / 65536;
                      if (prior == index) priorCount = patternIndex;
                      for (priorPattern in 0..<priorCount) {
                        val priorRoot = whenPatternRoot(
                            semantic, roots[prior as u64], valueForm,
                            priorPattern);
                        val priorCondition = semantic.nodes.data[priorRoot];
                        if (priorCondition.kind == AstKind.Member &&
                                priorCondition.typeKind == TypeKind.Enum.value &&
                                priorCondition.typeName == subject.name &&
                                priorCondition.conversionKind == condition.conversionKind) {
                            var diagnostic = condition;
                            diagnostic.start = semantic.nodes.data[
                                condition.subtreeStart].start;
                            semanticFail(semantic, 1, diagnostic);
                            return false;
                        }
                      }
                    }
                }
                unique++;
            }
          }
        }
    }

    return unique == declaration.aux;
}

fn functionIsExtern(function: AstNode) => (function.aux / 65536) % 2 == 1;

fn functionInfersReturn(function: AstNode) => (function.storage / 2) % 2 == 1;

fn inferFunctionReturn(var semantic: Semantic, functionRoot: u64): TypeValue {
    var function = semantic.nodes.data[functionRoot];
    if ((function.storage / 8) % 2 == 1)
        return TypeValue(typeKindFromValue(function.typeKind), function.typeName, function.typePointee);
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
        semantic.locals.add(
            LocalInfo(
                nodeHash(semantic, nameNode),
                typeFromNode(semantic, parameterRoot - 1),
                parameter.aux != 1, nameNode.start, false, false
            )
		);
    }
    val statementRoot = functionRoot - 2;
    val statement = semantic.nodes.data[statementRoot];
    var inferred = unitType();
    if (statement.kind == AstKind.ReturnStatement) {
        val expressionRoot = statementRoot - 1;
        inferred = expressionType(semantic, expressionRoot);
        if (inferred.kind == TypeKind.Unit ||
            semantic.nodes.data[expressionRoot].kind == AstKind.Assignment) {
            inferred = unitType();
            var expressionStatement = statement;
            expressionStatement.kind = AstKind.ExpressionStatement;
            semantic.nodes.data[statementRoot] = expressionStatement;
        }
    } else {
        semantic.returnType = unitType();
        checkStatement(semantic, statementRoot);
    }
    function = semantic.nodes.data[functionRoot];
    function.typeKind = inferred.kind.value;
    function.typeName = inferred.name;
    function.typePointee = inferred.pointee;
    function.storage = function.storage - 4 + 8;
    semantic.nodes.data[functionRoot] = function;
    semantic.locals.setLength(savedLength);
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

fn functionTypeParameterRoot(val semantic: Semantic, functionRoot: u64, position: u32): u64 {
    val function = semantic.nodes.data[functionRoot];
    var root = functionReturnRoot(semantic, functionRoot);
    val parameters = functionParameterCount(function);
    for (parameter in 0..<parameters) {
        root = semantic.nodes.data[root].subtreeStart - 1;
    }
    val remaining = functionTypeParameterCount(function);
    for (index in position - 1..<remaining) {
        root = semantic.nodes.data[root].subtreeStart - 1;
    }
    return root;
}

fn structTypeParameterCount(structure: AstNode) => structure.aux / 65536;

fn structFieldCount(structure: AstNode) => structure.aux % 65536;

fn structMethodCount(structure: AstNode) => structure.storage;

fn rootBeforeStructMethods(val nodes: List<AstNode>, structureRoot: u64): u64 {
    var root = structureRoot - 1;
    val remaining = structMethodCount(nodes.data[structureRoot]);
    for (method in 0..<remaining) {
        root = nodes.data[root].subtreeStart - 1;
    }
    return root;
}

fn methodHash(owner: u64, name: u64) => owner * 33 + name;

fn methodOwnerStructRoot(
    val semantic: Semantic, functionRoot: u64): u64 {
    val function = semantic.nodes.data[functionRoot];
    if (function.conversionKind == 1) {
        if (functionParameterCount(function) == 0) return semantic.nodes.length;
        val receiverType = semantic.nodes.data[
            functionParameterRoot(semantic, functionRoot, 1) - 1];
        val structure = declarationFind(
            semantic.structs, nodeHash(semantic, receiverType));
        if (structure == semantic.structs.length) return semantic.nodes.length;
        return semantic.structs.data[structure].node;
    }
    if (function.conversionKind != 2) return semantic.nodes.length;
    for (structureIndex in 0..<semantic.structs.length) {
        val structureRoot = semantic.structs.data[structureIndex].node;
        var methodRoot = structureRoot - 1;
        val methodCount = structMethodCount(semantic.nodes.data[structureRoot]);
        for (methodIndex in 0..<methodCount) {
            if (methodRoot == functionRoot) return structureRoot;
            methodRoot = semantic.nodes.data[methodRoot].subtreeStart - 1;
        }
    }
    return semantic.nodes.length;
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

fn structTypeParameterRoot(val semantic: Semantic, structureRoot: u64, position: u32): u64 {
    val structure = semantic.nodes.data[structureRoot];
    var root = rootBeforeStructMethods(semantic.nodes, structureRoot);
    val fields = structFieldCount(structure);
    for (field in 0..<fields) {
        root = semantic.nodes.data[root].subtreeStart - 1;
    }
    val remaining = structTypeParameterCount(structure);
    for (index in position..<remaining) {
        root = semantic.nodes.data[root].subtreeStart - 1;
    }
    return root;
}

fn structTypeParameterPosition(val semantic: Semantic, structureRoot: u64, name: u64): u32 {
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

fn fieldRootAt(val nodes: List<AstNode>, structureRoot: u64, wanted: u32): u64 {
    val structure = nodes.data[structureRoot];
    var roots = k_boot_alloc((structFieldCount(structure) as u64) * sizeof(u64)) as u64*;
    var root = rootBeforeStructMethods(nodes, structureRoot);
    val remaining = structFieldCount(structure);
    for (index in remaining>..0) {
        roots[index as u64] = root;
        root = nodes.data[root].subtreeStart - 1;
    }
    val result = roots[wanted as u64];
    k_boot_free(roots as unit*);
    return result;
}

fn substituteStructType(
    var semantic: Semantic, structureRoot: u64,
    type: TypeValue, val arguments: List<TypeValue>,
    argumentStart: u64, count: u32
): TypeValue {
    if (type.kind == TypeKind.TypeParameter) {
        val position =
            structTypeParameterPosition(semantic, structureRoot, type.name);
        if (position >= count) return invalidType();
        return arguments.data[argumentStart + position as u64];
    }
    if (type.kind == TypeKind.Struct) {
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
        return TypeValue(TypeKind.Struct, type.name, newStart as u32 + argCount * 65536);
    }
    if (type.kind == TypeKind.Nullable) {
        val inner = substituteStructType(
            semantic, structureRoot,
            TypeValue(typeKindFromValue(type.pointee), type.name, 0), arguments, argumentStart, count);
        return TypeValue(TypeKind.Nullable, inner.name, inner.kind.value);
    }
    if (type.kind == TypeKind.Pointer) {
        val inner = substituteStructType(
            semantic, structureRoot,
            TypeValue(typeKindFromValue(type.pointee), type.name, 0), arguments, argumentStart, count);
        return TypeValue(TypeKind.Pointer, inner.name, inner.kind.value);
    }
    if (type.kind == TypeKind.Slice) {
        val inner = substituteStructType(
            semantic, structureRoot,
            TypeValue(typeKindFromValue(type.pointee), type.name, 0), arguments, argumentStart, count);
        return TypeValue(TypeKind.Slice, inner.name, inner.kind.value);
    }
    return type;
}

fn findCurrentTypeParameter(
    val semantic: Semantic, name: u64): TypeValue {
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
                return TypeValue(TypeKind.TypeParameter, name, constraint);
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
                return TypeValue(TypeKind.TypeParameter, name, constraint);
            }
        }
    }
    return invalidType();
}

fn typeParameterPosition(
    val semantic: Semantic, functionRoot: u64, name: u64): u32 {
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
    var semantic: Semantic, functionRoot: u64,
    type: TypeValue, arguments: TypeValue*, count: u32): TypeValue {
    if (type.kind == TypeKind.Struct) {
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
        return TypeValue(TypeKind.Struct, type.name, newStart as u32 + argumentCount * 65536);
    }
    if (type.kind == TypeKind.Nullable) {
        val inner = substituteGenericType(
            semantic, functionRoot,
            TypeValue(typeKindFromValue(type.pointee), type.name, 0), arguments, count);
        if (inner.kind == TypeKind.Invalid) return inner;
        return TypeValue(TypeKind.Nullable, inner.name, inner.kind.value);
    }
    if (type.kind != TypeKind.TypeParameter) return type;
    val position =
        typeParameterPosition(semantic, functionRoot, type.name);
    if (position >= count) return invalidType();
    return arguments[position as u64];
}

fn constraintAcceptsType(constraint: u32, type: TypeValue): bool {
    if (constraint == 0) {
        if (type.kind == TypeKind.Invalid) return false;
        if (type.kind == TypeKind.Unit) return false;
        return true;
    }
    if (type.kind == TypeKind.TypeParameter) {
        return type.pointee >= constraint;
    }
    val integer = type.isInteger() || type.kind == TypeKind.IntegerLiteral;
    return when (constraint) {
        1 -> type.kind == TypeKind.Bool || integer;
        2, 3, 4 -> integer;
        5 -> type.kind == TypeKind.U8 || type.kind == TypeKind.U32 ||
            type.kind == TypeKind.U64 || type.kind == TypeKind.IntegerLiteral;
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
            if (structTypeParameterCount(structure) > 0) {
                if (root == functionParameterRoot(
                        semantic, semantic.currentFunction, 1) - 1) {
                    val count = structTypeParameterCount(structure);
                    val start = semantic.genericArguments.length;
                    for (position in 0..<count) {
                        val parameterRoot = structTypeParameterRoot(
                            semantic, semantic.currentStruct, position + 1);
                        val parameter = semantic.nodes.data[parameterRoot];
                        val nameNode = semantic.nodes.data[parameter.subtreeStart];
                        var constraint: u32 = 0;
                        if (parameter.aux == 1) {
                            constraint = constraintFromHash(nodeHash(
                                semantic, semantic.nodes.data[parameterRoot - 1]));
                        }
                        semantic.genericArguments.add(TypeValue(TypeKind.TypeParameter, nodeHash(semantic, nameNode), constraint));
                    }
                    val ownerName = semantic.nodes.data[structure.subtreeStart];
                    value = TypeValue(
                        TypeKind.Struct, nodeHash(semantic, ownerName),
                        start as u32 + count * 65536);
                }
            }
        }
        }
    }
    if (value.kind == TypeKind.Invalid) value = inferTypeFromNode(semantic, root);
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
    if (node.kind == AstKind.NamedType) {
        val tokenKind = node.aux % 256;
        val primitive = primitiveType(tokenKind);
        if (primitive.kind != TypeKind.Invalid) return primitive;
        val parameter = findCurrentTypeParameter(
            semantic, nodeHash(semantic, node));
        if (parameter.kind != TypeKind.Invalid) return parameter;
        
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
            return TypeValue(TypeKind.Struct, nodeHash(semantic, node), start as u32 + typeArgumentCount * 65536);
        }
        
        val name = nodeHash(semantic, node);
        val enumIndex = declarationFind(semantic.enums, name);
        if (enumIndex != semantic.enums.length) {
            val enumeration = semantic.nodes.data[semantic.enums.data[enumIndex].node];
            return TypeValue(TypeKind.Enum, name, enumeration.typePointee);
        }
        return TypeValue(TypeKind.Struct, name, 0);
    }
    if (node.kind == AstKind.PointerType) {
        val inner = typeFromNode(semantic, root - 1);
        if (inner.kind == TypeKind.Pointer) {
            return TypeValue(TypeKind.Pointer, inner.pointee as u64, TypeKind.Pointer.value);
        }
        return TypeValue(TypeKind.Pointer, inner.name, inner.kind.value);
    }
    if (node.kind == AstKind.SliceType) {
        val inner = typeFromNode(semantic, root - 1);
        return TypeValue(TypeKind.Slice, inner.name, inner.kind.value);
    }
    if (node.kind == AstKind.ArrayType) {
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
    if (node.kind == AstKind.NullableType) {
        val inner = typeFromNode(semantic, root - 1);
        return TypeValue(TypeKind.Nullable, inner.name, inner.kind.value);
    }
    return invalidType();
}

fn functionReturnRoot(val semantic: Semantic, functionRoot: u64): u64 {
    val function = semantic.nodes.data[functionRoot];
    if (functionIsExtern(function)) return functionRoot - 1;
    val body = semantic.nodes.data[functionRoot - 1];
    return body.subtreeStart - 1;
}

fn functionParameterRoot(
    val semantic: Semantic, functionRoot: u64, position: u32): u64 {
    val function = semantic.nodes.data[functionRoot];
    var root = functionReturnRoot(semantic, functionRoot);
    val remaining = functionParameterCount(function);
    for (index in position - 1..<remaining) {
        root = semantic.nodes.data[root].subtreeStart - 1;
    }
    return root;
}

fn functionParameterCount(function: AstNode) => function.aux % 65536;

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
    if (node.kind != AstKind.Literal ||
        node.aux != TokenKind.StringLiteral.value) return actual;
    if (expected.kind != TypeKind.Slice || expected.pointee != TypeKind.U8.value) return actual;
    var typed = node;
    typed.typeKind = expected.kind.value;
    typed.typeName = expected.name;
    typed.typePointee = expected.pointee;
    semantic.nodes.data[root] = typed;
    return expected;
}

fn typeNeedsOwnership(val semantic: Semantic, value: TypeValue): bool {
    if (value.kind == TypeKind.String || value.kind == TypeKind.TypeParameter || value.kind == TypeKind.Array) return true;
    if (value.kind == TypeKind.Nullable) {
        return typeNeedsOwnership(
            semantic, TypeValue(typeKindFromValue(value.pointee), value.name, 0));
    }
    if (value.kind != TypeKind.Struct) return false;
    val method = declarationFind(
        semantic.functions, methodHash(value.name, 6385234055));
    if (method == semantic.functions.length) return false;
    val functionRoot = semantic.functions.data[method].node;
    val function = semantic.nodes.data[functionRoot];
    if (functionParameterCount(function) == 0) return false;
    return semantic.nodes.data[
        functionParameterRoot(semantic, functionRoot, 1)].aux == 0;
}

fn markOwnerRootMoved(var semantic: Semantic, root: u64) {
    val node = semantic.nodes.data[root];
    if (node.kind == AstKind.Identifier) {
        val local = localFind(semantic.locals, nodeHash(semantic, node));
        if (local != semantic.locals.length) {
            var value = semantic.locals.data[local];
            value.moved = true;
            semantic.locals.data[local] = value;
            var movedNode = semantic.nodes.data[root];
            if (movedNode.ownership % 2 == 0) movedNode.ownership++;
            semantic.nodes.data[root] = movedNode;
        }
        return;
    }
    if (node.kind == AstKind.Member || node.kind == AstKind.Postfix) {
        markOwnerRootMoved(semantic, root - 1);
        return;
    }
    if (node.kind == AstKind.Index) {
        val indexRoot = root - 1;
        val objectRoot = semantic.nodes.data[indexRoot].subtreeStart - 1;
        if (semantic.nodes.data[objectRoot].typeKind == TypeKind.Array.value) {
            markOwnerRootMoved(semantic, objectRoot);
        }
    }
}

fn markExpressionMoved(var semantic: Semantic, root: u64) {
    if (semantic.suppressMoves) return;
    val node = semantic.nodes.data[root];
    val value = TypeValue(typeKindFromValue(node.typeKind), node.typeName, node.typePointee);
    if (!typeNeedsOwnership(semantic, value)) return;
    if (node.kind == AstKind.IfExpression) {
        val elseValueRoot = root - 1;
        var thenValueRoot = semantic.nodes.data[elseValueRoot].subtreeStart - 1;
        for (index in 0..<node.aux / 65536) {
            thenValueRoot = semantic.nodes.data[thenValueRoot].subtreeStart - 1;
        }
        markExpressionMoved(semantic, thenValueRoot);
        markExpressionMoved(semantic, elseValueRoot);
        return;
    }
    if (node.kind == AstKind.WhenExpression) {
        var branchRoot = root - 1;
        for (index in node.aux % 65536>..0) {
            markExpressionMoved(semantic, branchRoot - 1);
            branchRoot = semantic.nodes.data[branchRoot].subtreeStart - 1;
        }
        return;
    }
    if (node.kind == AstKind.ArrayLiteral) {
        var childRoot = root - 1;
        for (index in 0..<node.aux) {
            markExpressionMoved(semantic, childRoot);
            childRoot = semantic.nodes.data[childRoot].subtreeStart - 1;
        }
        return;
    }
    markOwnerRootMoved(semantic, root);
}

fn captureOwnership(val semantic: Semantic, count: u64): u8* {
    val states = k_boot_alloc(count) as u8*;
    for (index in 0..<count) {
        states[index] = if (semantic.locals.data[index].moved)
            1 as u8 else 0 as u8;
    }
    return states;
}

fn restoreOwnership(var semantic: Semantic, states: u8*, count: u64) {
    for (index in 0..<count) {
        var local = semantic.locals.data[index];
        local.moved = states[index] == 1;
        semantic.locals.data[index] = local;
    }
}

fn mergeOwnership(
    var semantic: Semantic, left: u8*, right: u8*, count: u64) {
    for (index in 0..<count) {
        var local = semantic.locals.data[index];
        local.moved = left[index] == 1 || right[index] == 1;
        semantic.locals.data[index] = local;
    }
}

fn includeCurrentOwnership(
    val semantic: Semantic, states: u8*, count: u64) {
    for (index in 0..<count) {
        if (semantic.locals.data[index].moved) states[index] = 1 as u8;
    }
}

fn inferExpressionType(var semantic: Semantic, root: u64): TypeValue {
    if (!semantic.result.ok) return invalidType();
    val node = semantic.nodes.data[root];
    if (node.kind == AstKind.Identifier) {
        val name = nodeHash(semantic, node);
        val local = localFind(semantic.locals, name);
        if (local != semantic.locals.length) {
            if (semantic.locals.data[local].moved) {
                semanticFail(semantic, 4, node);
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
            return TypeValue(TypeKind.Function, name, 0);
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
        semanticFail(semantic, 2, node);
        return invalidType();
    }
    if (node.kind == AstKind.Literal) {
        return when (node.aux) {
            TokenKind.IntegerLiteral.value -> integerLiteralType();
            TokenKind.FloatLiteral.value -> TypeValue(TypeKind.F64, 0, 0);
            TokenKind.StringLiteral.value -> TypeValue(TypeKind.String, 0, 0);
            TokenKind.KwTrue.value, TokenKind.KwFalse.value -> boolType();
            TokenKind.KwNull.value -> TypeValue(TypeKind.NullLiteral, 0, 0);
            else -> invalidType();
        };
    }
    if (node.kind == AstKind.Unary) {
        val operand = expressionType(semantic, root - 1);
        if (node.aux == TokenKind.Star.value) {
            if (operand.kind != TypeKind.Pointer) {
                semanticFail(semantic, 4, node);
                return invalidType();
            }
            if (operand.pointee == TypeKind.Pointer.value) {
                return TypeValue(TypeKind.Pointer, 0, operand.name as u32);
            }
            return TypeValue(typeKindFromValue(operand.pointee), operand.name, 0);
        }
        if (node.aux == TokenKind.Ampersand.value) {
            if (operand.kind == TypeKind.Pointer) {
                return TypeValue(TypeKind.Pointer, operand.pointee as u64, TypeKind.Pointer.value);
            }
            return TypeValue(TypeKind.Pointer, operand.name, operand.kind.value);
        }
        if (node.aux == TokenKind.Bang.value) {
            if (operand.kind != TypeKind.Bool) {
                semanticFail(semantic, 4, node);
                return invalidType();
            }
            return TypeValue(TypeKind.Bool, 0, 0);
        }
        return operand;
    }
    if (node.kind == AstKind.Binary) {
        val rightRoot = root - 1;
        val leftRoot = semantic.nodes.data[rightRoot].subtreeStart - 1;
        if (node.aux == TokenKind.KwIn.value) {
            val range = semantic.nodes.data[rightRoot];
            var validRange = range.kind == AstKind.Binary;
            if (validRange) {
                validRange = range.aux == TokenKind.Range.value ||
                    range.aux == TokenKind.RangeExclusive.value ||
                    range.aux == TokenKind.RangeExclusiveStart.value ||
                    range.aux == TokenKind.RangeExclusiveBoth.value;
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
            if (lower.kind == TypeKind.IntegerLiteral) {
                lower = subject;
                var lowerNode = semantic.nodes.data[lowerRoot];
                lowerNode.typeKind = subject.kind.value;
                semantic.nodes.data[lowerRoot] = lowerNode;
            }
            if (upper.kind == TypeKind.IntegerLiteral) {
                upper = subject;
                var upperNode = semantic.nodes.data[upperRoot];
                upperNode.typeKind = subject.kind.value;
                semantic.nodes.data[upperRoot] = upperNode;
            }
            if (!subject.isInteger() && !subject.isFloat())
                semanticFail(semantic, 4, node);
            if (!typeAccepts(subject, lower, semantic.genericArguments) ||
                !typeAccepts(subject, upper, semantic.genericArguments))
                semanticFail(semantic, 4, node);
            var typedRange = range;
            typedRange.typeKind = subject.kind.value;
            typedRange.typeName = subject.name;
            typedRange.typePointee = subject.pointee;
            semantic.nodes.data[rightRoot] = typedRange;
            return boolType();
        }
        val left = expressionType(semantic, leftRoot);
        val right = expressionType(semantic, rightRoot);
        var logical = node.aux == TokenKind.AndAnd.value;
        if (node.aux == TokenKind.OrOr.value) logical = true;
        if (logical) {
            if (left.kind != TypeKind.Bool) semanticFail(semantic, 4, node);
            else {
                if (right.kind != TypeKind.Bool) semanticFail(semantic, 4, node);
            }
            return boolType();
        }
        var comparison = node.aux == TokenKind.Less.value;
        if (node.aux == TokenKind.Greater.value) comparison = true;
        if (node.aux == TokenKind.EqualEqual.value) comparison = true;
        if (node.aux == TokenKind.BangEqual.value) comparison = true;
        if (node.aux == TokenKind.LessEqual.value) comparison = true;
        if (node.aux == TokenKind.GreaterEqual.value) comparison = true;
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
    if (node.kind == AstKind.Assignment) {
        val rightRoot = root - 1;
        val leftRoot = semantic.nodes.data[rightRoot].subtreeStart - 1;
        val target = semantic.nodes.data[leftRoot];
        var targetLocal = semantic.locals.length;
        if (target.kind == AstKind.Identifier) {
            targetLocal = localFind(semantic.locals, nodeHash(semantic, target));
            if (targetLocal == semantic.locals.length) {
                semanticFail(semantic, 2, target);
                return invalidType();
            }
            if (!semantic.locals.data[targetLocal].mutable) {
                semanticFail(semantic, 7, target);
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
            if (node.aux != TokenKind.Equal.value &&
                semantic.locals.data[targetLocal].moved) {
                semanticFail(semantic, 4, target);
                return left;
            }
        } else {
            left = expressionType(semantic, leftRoot);
        }
        var right = expressionType(semantic, rightRoot);
        right = contextualizeLiteralByteSlice(
            semantic, rightRoot, left, right);
        if (!typeAccepts(left, right, semantic.genericArguments)) {
            semanticFail(semantic, 4, node);
        } else if (node.aux == TokenKind.Equal.value) {
            markExpressionMoved(semantic, rightRoot);
            if (targetLocal != semantic.locals.length) {
                var reassigned = semantic.locals.data[targetLocal];
                reassigned.moved = false;
                semantic.locals.data[targetLocal] = reassigned;
            }
        }
        return left;
    }
    if (node.kind == AstKind.Cast) {
        val typeRoot = root - 1;
        val valueRoot = semantic.nodes.data[typeRoot].subtreeStart - 1;
        var source = expressionType(semantic, valueRoot);
        val target = typeFromNode(semantic, typeRoot);
        if (source.kind == TypeKind.IntegerLiteral) {
            source = TypeValue(TypeKind.I32, 0, 0);
            var valueNode = semantic.nodes.data[valueRoot];
            valueNode.typeKind = source.kind.value;
            semantic.nodes.data[valueRoot] = valueNode;
        }
        var pointerCast = false;
        if (source.kind == TypeKind.Pointer) {
            if (target.kind == TypeKind.Pointer) pointerCast = true;
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
    if (node.kind == AstKind.Call) {
        var argumentCount = node.aux % 65536;
        val callExplicitTypeCount = node.aux / 65536;
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
        if (callee.kind == AstKind.Member) explicitTypeCount = callee.aux;
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
        if (callee.kind == AstKind.Identifier) {
            functionName = nodeHash(semantic, callee);
        } else {
            if (callee.kind == AstKind.Member) {
                val objectRoot = associatedObjectRoot(semantic, cursor);
                val objectNode = semantic.nodes.data[objectRoot];
                if (objectNode.kind == AstKind.Identifier) {
                    val structureIndex = declarationFind(
                        semantic.structs, nodeHash(semantic, objectNode));
                    if (structureIndex != semantic.structs.length) {
                        val candidateName = methodHash(
                            semantic.structs.data[structureIndex].name,
                            nodeHash(semantic, callee));
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
                    if (object.kind == TypeKind.Struct) {
                        for (argument in argumentCount>..0) {
                            argumentRoots[argument as u64 + 1] =
                                argumentRoots[argument as u64];
                        }
                        argumentRoots[0] = objectRoot;
                        argumentCount++;
                        functionName = methodHash(
                            object.name, nodeHash(semantic, callee));
                    }
                }
            }
        }
        if (functionName == 0) {
            semanticFail(semantic, 2, callee);
            k_boot_free(explicitTypeRoots as unit*);
            k_boot_free(argumentRoots as unit*);
            return invalidType();
        }
        val functionIndex = declarationFind(semantic.functions, functionName);
        if (functionIndex == semantic.functions.length) {
            if (callee.kind == AstKind.Identifier &&
                functionName == 210727929557 &&
                localFind(semantic.locals, functionName) == semantic.locals.length) {
                if (argumentCount != 2) {
                    semanticFail(semantic, 3, callee);
                    k_boot_free(explicitTypeRoots as unit*);
                    k_boot_free(argumentRoots as unit*);
                    return invalidType();
                }
                val pointer = expressionType(semantic, argumentRoots[0]);
                val length = expressionType(semantic, argumentRoots[1]);
                if (pointer.kind != TypeKind.Pointer || pointer.pointee == TypeKind.Unit.value) {
                    semanticFail(semantic, 4, semantic.nodes.data[argumentRoots[0]]);
                    k_boot_free(explicitTypeRoots as unit*);
                    k_boot_free(argumentRoots as unit*);
                    return invalidType();
                }
                if (!typeAccepts(
                        TypeValue(TypeKind.U64, 0, 0), length,
                        semantic.genericArguments)) {
                    semanticFail(semantic, 4, semantic.nodes.data[argumentRoots[1]]);
                    k_boot_free(explicitTypeRoots as unit*);
                    k_boot_free(argumentRoots as unit*);
                    return invalidType();
                }
                k_boot_free(explicitTypeRoots as unit*);
                k_boot_free(argumentRoots as unit*);
                return TypeValue(TypeKind.Slice, pointer.name, pointer.pointee);
            }
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
            val structureIndex = declarationFind(semantic.structs, nodeHash(semantic, callee));
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
                if (pattern.kind == TypeKind.TypeParameter) {
                    val position = structTypeParameterPosition(
                        semantic, structureRoot, pattern.name);
                    if (explicitTypeCount == 0) {
                        var inferredActual = actual;
                        if (inferredActual.kind == TypeKind.IntegerLiteral) {
                            inferredActual = TypeValue(TypeKind.I32, 0, 0);
                        }
                        if (typeArguments[position as u64].kind == TypeKind.Invalid) {
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
                    if (actual.kind == TypeKind.IntegerLiteral) {
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
                if (!typeAccepts(expected, actual, semantic.genericArguments)) {
                    semanticFail(
                        semantic, 4,
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
            k_boot_free(typeArguments as unit*);
            k_boot_free(explicitTypeRoots as unit*);
            k_boot_free(argumentRoots as unit*);
            return TypeValue(
                TypeKind.Struct, semantic.structs.data[structureIndex].name, start + typeCount * 65536);
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
                if (receiverNode.kind == AstKind.Identifier) {
                    val receiverLocal =
                        localFind(semantic.locals, nodeHash(semantic, receiverNode));
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
        val methodOwner = methodOwnerStructRoot(semantic, functionRoot);
        val typeCount = if (methodOwner != semantic.nodes.length)
                structTypeParameterCount(semantic.nodes.data[methodOwner])
            else functionTypeParameterCount(function);
        if (associated) {
            if (explicitTypeCount != typeCount) {
                semanticFail(semantic, 3, callee);
                k_boot_free(explicitTypeRoots as unit*);
                k_boot_free(argumentRoots as unit*);
                return invalidType();
            }
        } else if (explicitTypeCount > 0) {
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
        for (explicit in 0..<typeCount) {
            typeArguments[explicit as u64] = invalidType();
        }
        if (methodOwner != semantic.nodes.length) {
            if (associated) {
                for (explicit in 0..<explicitTypeCount) {
                    typeArguments[explicit as u64] =
                        typeFromNode(
                            semantic,
                            explicitTypeRoots[explicit as u64]);
                }
            } else {
                val receiver = expressionType(semantic, argumentRoots[0]);
                val start = receiver.pointee % 65536;
                val count = receiver.pointee / 65536;
                if (receiver.kind != TypeKind.Struct || count != typeCount) {
                    semanticFail(semantic, 4, callee);
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
            var actual = expressionType(
                semantic, argumentRoots[argument as u64]);
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
            if (pattern.kind == TypeKind.TypeParameter) {
                var position = typeParameterPosition(
                    semantic, functionRoot, pattern.name);
                if (methodOwner != semantic.nodes.length) {
                    position = structTypeParameterPosition(
                        semantic, methodOwner, pattern.name);
                }
                if (explicitTypeCount == 0 &&
                    methodOwner == semantic.nodes.length) {
                    var inferredActual = actual;
                    if (inferredActual.kind == TypeKind.IntegerLiteral) {
                        inferredActual = TypeValue(TypeKind.I32, 0, 0);
                    }
                    if (typeArguments[position as u64].kind == TypeKind.Invalid) {
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
            if (!typeAccepts(expected, actual, semantic.genericArguments)) {
                semanticFail(
                    semantic, 4,
                    semantic.nodes.data[
                        argumentRoots[argument as u64]]);
            }
            if (semantic.nodes.data[parameterRoot].aux == 0) {
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
    if (node.kind == AstKind.Member) {
        val objectRoot = root - 1;
        val objectNode = semantic.nodes.data[objectRoot];
        if (objectNode.kind == AstKind.Identifier) {
            val enumIndex = declarationFind(semantic.enums, nodeHash(semantic, objectNode));
            if (enumIndex != semantic.enums.length) {
                val enumRoot = semantic.enums.data[enumIndex].node;
                val enumeration = semantic.nodes.data[enumRoot];
                val wanted = nodeHash(semantic, node);
                for (position in 0..<enumeration.aux) {
                    val variant = semantic.nodes.data[
                        enumVariantStart(enumeration) + position as u64];
                    if (nodeHash(semantic, variant) == wanted) {
                        var resolvedObject = objectNode;
                        resolvedObject.typeKind = TypeKind.Enum.value;
                        resolvedObject.typeName = semantic.enums.data[enumIndex].name;
                        resolvedObject.typePointee = enumeration.typePointee;
                        semantic.nodes.data[objectRoot] = resolvedObject;
                        var resolved = node;
                        resolved.storage = variant.storage;
                        resolved.conversionKind = position;
                        resolved.typeKind = TypeKind.Enum.value;
                        resolved.typeName = semantic.enums.data[enumIndex].name;
                        resolved.typePointee = enumeration.typePointee;
                        semantic.nodes.data[root] = resolved;
                        return TypeValue(
                            TypeKind.Enum, resolved.typeName,
                            enumeration.typePointee);
                    }
                }
                semanticFail(semantic, 2, node);
                return invalidType();
            }
        }
        val object = expressionType(semantic, objectRoot);
        if (object.kind == TypeKind.Enum) {
            if (nodeHash(semantic, node) == 210731095874) {
                var resolved = node;
                resolved.typeKind = object.pointee;
                semantic.nodes.data[root] = resolved;
                return TypeValue(typeKindFromValue(object.pointee), 0, 0);
            }
            semanticFail(semantic, 8, node);
            return invalidType();
        }
        if (object.kind == TypeKind.String) {
            if (nodeHash(semantic, node) == 210708248140) {
                return TypeValue(TypeKind.Slice, 0, TypeKind.U8.value);
            }
            semanticFail(semantic, 8, node);
            return invalidType();
        }
        if (object.kind != TypeKind.Struct) {
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
        val remaining = structFieldCount(structure);
        for (fieldIndex in 0..<remaining) {
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
        }
        semanticFail(semantic, 8, node);
        return invalidType();
    }
    if (node.kind == AstKind.Index) {
        val indexRoot = root - 1;
        val objectRoot = semantic.nodes.data[indexRoot].subtreeStart - 1;
        val object = expressionType(semantic, objectRoot);
        expressionType(semantic, indexRoot);
        if (object.kind == TypeKind.Array) {
            return object.arrayElement();
        }
        if (object.kind == TypeKind.Slice) {
            return TypeValue(typeKindFromValue(object.pointee), object.name, 0);
        }
        if (object.kind != TypeKind.Pointer) {
            semanticFail(semantic, 8, node);
            return invalidType();
        }
        if (object.pointee == TypeKind.Pointer.value) {
            return TypeValue(TypeKind.Pointer, 0, object.name as u32);
        }
        return TypeValue(typeKindFromValue(object.pointee), object.name, 0);
    }
    if (node.kind == AstKind.Postfix) {
        val operand = expressionType(semantic, root - 1);
        if (node.aux == TokenKind.PlusPlus.value ||
            node.aux == TokenKind.MinusMinus.value) {
            if (semantic.mutationRoot != root) semanticFail(semantic, 4, node);
            if (!operand.isFloat() && !operand.isInteger())
                semanticFail(semantic, 4, node);
            val target = semantic.nodes.data[root - 1];
            if (target.kind == AstKind.Identifier) {
                val local = localFind(semantic.locals, nodeHash(semantic, target));
                if (local == semantic.locals.length) semanticFail(semantic, 2, target);
                else {
                    if (!semantic.locals.data[local].mutable)
                        semanticFail(semantic, 7, target);
                }
            }
            return operand;
        }
        if (operand.kind != TypeKind.Nullable) {
            semanticFail(semantic, 4, node);
            return invalidType();
        }
        return TypeValue(typeKindFromValue(operand.pointee), operand.name, 0);
    }
    if (node.kind == AstKind.IfExpression) {
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
        if (condition.kind != TypeKind.Bool) {
            semanticFail(semantic, 6, semantic.nodes.data[childRoot]);
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
        if (!typeAccepts(thenType, elseType, semantic.genericArguments)) {
            semanticFail(semantic, 4, semantic.nodes.data[elseValueRoot]);
        }
        var resolved = semantic.nodes.data[root];
        resolved.typeKind = thenType.kind.value;
        resolved.typeName = thenType.name;
        resolved.typePointee = thenType.pointee;
        semantic.nodes.data[root] = resolved;
        return thenType;
    }
    if (node.kind == AstKind.WhenExpression) {
        val branchCount = node.aux % 65536;
        val hasSubject = node.aux / 65536;
        val roots = k_boot_alloc((branchCount as u64) * sizeof(u64)) as u64*;
        var branchRoot = root - 1;
        for (index in branchCount>..0) {
            roots[index as u64] = branchRoot;
            branchRoot = semantic.nodes.data[branchRoot].subtreeStart - 1;
        }
        var subject = invalidType();
        if (hasSubject == 1) {
            subject = expressionType(semantic, branchRoot);
            if (subject.kind == TypeKind.IntegerLiteral) {
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
            if (branch.aux % 2 == 1) hasElse = true;
            val valueRoot = roots[index as u64] - 1;
            val statementCount = (branch.aux % 65536) / 2;
            val statementRoots =
                k_boot_alloc((statementCount as u64) * sizeof(u64)) as u64*;
            var beforeValue = semantic.nodes.data[valueRoot].subtreeStart - 1;
            for (statementIndex in statementCount>..0) {
                statementRoots[statementIndex as u64] = beforeValue;
                beforeValue = semantic.nodes.data[beforeValue].subtreeStart - 1;
            }
            if (branch.aux % 2 == 0) {
              val patternCount = branch.aux / 65536;
              for (patternIndex in 0..<patternCount) {
                val conditionRoot = whenPatternRoot(
                    semantic, roots[index as u64], true, patternIndex);
                val condition = expressionType(semantic, conditionRoot);
                if (hasSubject == 1) {
                    if (!typeAccepts(subject, condition, semantic.genericArguments)) {
                        semanticFail(semantic, 4, semantic.nodes.data[conditionRoot]);
                    } else {
                        var conditionNode = semantic.nodes.data[conditionRoot];
                        conditionNode.typeKind = subject.kind.value;
                        conditionNode.typeName = subject.name;
                        conditionNode.typePointee = subject.pointee;
                        semantic.nodes.data[conditionRoot] = conditionNode;
                    }
                } else {
                    if (condition.kind != TypeKind.Bool) {
                        semanticFail(semantic, 6, semantic.nodes.data[conditionRoot]);
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
            if (result.kind == TypeKind.Invalid) {
                result = value;
            } else {
                if (!typeAccepts(result, value, semantic.genericArguments)) {
                    semanticFail(semantic, 4, semantic.nodes.data[valueRoot]);
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
            semanticFail(semantic, 4, node);
        }
        var resolved = semantic.nodes.data[root];
        resolved.typeKind = result.kind.value;
        resolved.typeName = result.name;
        resolved.typePointee = result.pointee;
        semantic.nodes.data[root] = resolved;
        k_boot_free(roots as unit*);
        return result;
    }
    if (node.kind == AstKind.ArrayLiteral) {
        if (node.aux == 0) return invalidType().array(0);
        var childRoot = root - 1;
        var element = expressionType(semantic, childRoot);
        if (element.kind == TypeKind.IntegerLiteral) element = TypeValue(TypeKind.I32, 0, 0);
        for (index in 0..<node.aux) {
            val actual = expressionType(semantic, childRoot);
            if (!typeAccepts(element, actual, semantic.genericArguments)) {
                semanticFail(semantic, 4, semantic.nodes.data[childRoot]);
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
    if (node.kind == AstKind.UnitLiteral) return unitType();
    if (node.kind == AstKind.Sizeof) {
        typeFromNode(semantic, root - 1);
        return TypeValue(TypeKind.U64, 0, 0);
    }
    return invalidType();
}

fn checkBlock(var semantic: Semantic, root: u64) {
    if (semantic.nodes.data[root].kind != AstKind.Block) {
        checkStatement(semantic, root);
        return;
    }
    val savedLocals = semantic.locals.length;
    val savedScopeStart = semantic.scopeStart;
    semantic.scopeStart = savedLocals;
    val block = semantic.nodes.data[root];
    val roots =
        k_boot_alloc((block.aux as u64) * sizeof(u64)) as u64*;
    var statementRoot = root - 1;
    for (index in block.aux>..0) {
        roots[index as u64] = statementRoot;
        statementRoot =
            semantic.nodes.data[statementRoot].subtreeStart - 1;
    }
    for (index in 0..<block.aux) {
        checkStatement(semantic, roots[index as u64]);
    }
    k_boot_free(roots as unit*);
    semantic.locals.setLength(savedLocals);
    semantic.scopeStart = savedScopeStart;
}

fn statementTerminates(val nodes: List<AstNode>, root: u64): bool {
    val node = nodes.data[root];
    if (node.kind == AstKind.ReturnStatement ||
        node.kind == AstKind.BreakStatement ||
        node.kind == AstKind.ContinueStatement) return true;
    if (node.kind == AstKind.Block) {
        if (node.aux == 0) return false;
        return statementTerminates(nodes, root - 1);
    }
    if (node.kind == AstKind.IfStatement && node.aux == 1) {
        val elseRoot = root - 1;
        val thenRoot = nodes.data[elseRoot].subtreeStart - 1;
        return statementTerminates(nodes, thenRoot) &&
            statementTerminates(nodes, elseRoot);
    }
    return false;
}

fn resolveWhenResultType(
    var semantic: Semantic, root: u64, target: TypeValue) {
    var whenNode = semantic.nodes.data[root];
    if (whenNode.kind != AstKind.WhenExpression) return;
    whenNode.typeKind = target.kind.value;
    whenNode.typeName = target.name;
    whenNode.typePointee = target.pointee;
    semantic.nodes.data[root] = whenNode;
    val branchCount = whenNode.aux % 65536;
    var branchRoot = root - 1;
    for (index in 0..<branchCount) {
        val valueRoot = branchRoot - 1;
        var valueNode = semantic.nodes.data[valueRoot];
        if (valueNode.typeKind == TypeKind.IntegerLiteral.value) {
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
    if (ifNode.kind != AstKind.IfExpression) return;
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
    if (valueNode.typeKind == TypeKind.IntegerLiteral.value) {
        valueNode.typeKind = target.kind.value;
        valueNode.typeName = target.name;
        valueNode.typePointee = target.pointee;
        semantic.nodes.data[thenValueRoot] = valueNode;
    }
    valueNode = semantic.nodes.data[elseValueRoot];
    if (valueNode.typeKind == TypeKind.IntegerLiteral.value) {
        valueNode.typeKind = target.kind.value;
        valueNode.typeName = target.name;
        valueNode.typePointee = target.pointee;
        semantic.nodes.data[elseValueRoot] = valueNode;
    }
}

fn checkStatement(var semantic: Semantic, root: u64) {
    if (!semantic.result.ok) return;
    val node = semantic.nodes.data[root];
    if (node.kind == AstKind.Block) {
        checkBlock(semantic, root);
        return;
    }
    if (node.kind == AstKind.IfStatement) {
        var thenRoot = root - 1;
        var elseRoot = semantic.nodes.length;
        if (node.aux == 1) {
            elseRoot = thenRoot;
            thenRoot = semantic.nodes.data[elseRoot].subtreeStart - 1;
        }
        val conditionRoot =
            semantic.nodes.data[thenRoot].subtreeStart - 1;
        if (expressionType(semantic, conditionRoot).kind != TypeKind.Bool) {
            semanticFail(
                semantic, 6, semantic.nodes.data[conditionRoot]);
        }
        val count = semantic.locals.length;
        val before = captureOwnership(semantic, count);
        checkBlock(semantic, thenRoot);
        val thenTerminates = statementTerminates(semantic.nodes, thenRoot);
        val thenState = captureOwnership(semantic, count);
        restoreOwnership(semantic, before, count);
        if (elseRoot != semantic.nodes.length) checkBlock(semantic, elseRoot);
        var elseTerminates = false;
        if (elseRoot != semantic.nodes.length)
            elseTerminates = statementTerminates(semantic.nodes, elseRoot);
        val elseState = captureOwnership(semantic, count);
        if (thenTerminates && !elseTerminates)
            restoreOwnership(semantic, elseState, count);
        else if (elseTerminates && !thenTerminates)
            restoreOwnership(semantic, thenState, count);
        else
            mergeOwnership(semantic, thenState, elseState, count);
        k_boot_free(elseState as unit*);
        k_boot_free(thenState as unit*);
        k_boot_free(before as unit*);
        return;
    }
    if (node.kind == AstKind.WhileStatement) {
        val bodyRoot = root - 1;
        semantic.loopDepth++;
        checkBlock(semantic, bodyRoot);
        semantic.loopDepth--;
        val conditionRoot =
            semantic.nodes.data[bodyRoot].subtreeStart - 1;
        if (expressionType(semantic, conditionRoot).kind != TypeKind.Bool) {
            semanticFail(
                semantic, 6, semantic.nodes.data[conditionRoot]);
        }
        return;
    }
    if (node.kind == AstKind.ForStatement) {
        val bodyRoot = root - 1;
        val collectionRoot =
            semantic.nodes.data[bodyRoot].subtreeStart - 1;
        var collectionNode = semantic.nodes.data[collectionRoot];
        var valueType = expressionType(semantic, collectionRoot);
        var range = collectionNode.kind == AstKind.Binary;
        if (range) {
            range = collectionNode.aux == TokenKind.Range.value;
            if (collectionNode.aux == TokenKind.RangeExclusive.value) range = true;
            if (collectionNode.aux == TokenKind.RangeExclusiveStart.value) range = true;
            if (collectionNode.aux == TokenKind.RangeExclusiveBoth.value) range = true;
        }
        if (range) {
            if (node.aux == 1) {
                semanticFail(
                    semantic, 4,
                    semantic.nodes.data[node.subtreeStart + 1]);
                return;
            }
        } else {
            var collection = valueType.kind == TypeKind.Slice;
            if (valueType.kind == TypeKind.Array) collection = true;
            if (!collection) {
                semanticFail(semantic, 4, collectionNode);
                return;
            }
            if (valueType.kind == TypeKind.Slice) {
                valueType = TypeValue(
                    typeKindFromValue(valueType.pointee), valueType.name, 0);
            } else {
                valueType = valueType.arrayElement();
            }
        }
        if (valueType.kind == TypeKind.IntegerLiteral) {
            valueType = TypeValue(TypeKind.I32, 0, 0);
            collectionNode.typeKind = TypeKind.I32.value;
            semantic.nodes.data[collectionRoot] = collectionNode;
            val rightRoot = collectionRoot - 1;
            val leftRoot =
                semantic.nodes.data[rightRoot].subtreeStart - 1;
            var rightNode = semantic.nodes.data[rightRoot];
            var leftNode = semantic.nodes.data[leftRoot];
            rightNode.typeKind = TypeKind.I32.value;
            leftNode.typeKind = TypeKind.I32.value;
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
        semantic.locals.add(LocalInfo(
            nodeHash(semantic, nameNode), valueType, false, nameNode.start,
            false, false));
        if (node.aux == 1) {
            val indexNode = semantic.nodes.data[node.subtreeStart + 1];
            semantic.locals.add(
                LocalInfo(
                    nodeHash(semantic, indexNode),
                    TypeValue(TypeKind.U64, 0, 0), false, indexNode.start, false, false
				)
			);
        }
        semantic.loopDepth++;
        checkBlock(semantic, bodyRoot);
        semantic.loopDepth--;
        semantic.locals.setLength(savedLocals);
        return;
    }
    if (node.kind == AstKind.WhenStatement) {
        val branchCount = node.aux % 65536;
        val hasSubject = node.aux / 65536;
        if (branchCount == 0) {
            semanticFail(semantic, 4, node);
            return;
        }
        val roots =
            k_boot_alloc((branchCount as u64) * sizeof(u64)) as u64*;
        var branchRoot = root - 1;
        for (index in branchCount>..0) {
            roots[index as u64] = branchRoot;
            branchRoot = semantic.nodes.data[branchRoot].subtreeStart - 1;
        }
        var subject = invalidType();
        if (hasSubject == 1) {
            val subjectRoot = branchRoot;
            subject = expressionType(semantic, subjectRoot);
            if (subject.kind == TypeKind.IntegerLiteral) {
                subject = TypeValue(TypeKind.I32, 0, 0);
                var subjectNode = semantic.nodes.data[subjectRoot];
                subjectNode.typeKind = TypeKind.I32.value;
                semantic.nodes.data[subjectRoot] = subjectNode;
            }
            var comparable = subject.kind == TypeKind.Bool;
            if (subject.isInteger()) comparable = true;
            if (subject.kind == TypeKind.Enum) comparable = true;
            if (!comparable) {
                semanticFail(semantic, 6, semantic.nodes.data[subjectRoot]);
            }
        }
        var hasElse = false;
        val ownershipCount = semantic.locals.length;
        val ownershipBefore = captureOwnership(semantic, ownershipCount);
        val ownershipMerged = k_boot_alloc(ownershipCount) as u8*;
        for (ownershipIndex in 0..<ownershipCount) {
            ownershipMerged[ownershipIndex] = 0 as u8;
        }
        for (index in 0..<branchCount) {
            restoreOwnership(semantic, ownershipBefore, ownershipCount);
            val current = semantic.nodes.data[roots[index as u64]];
            if (current.aux % 2 == 1) hasElse = true;
            val bodyRoot = roots[index as u64] - 1;
            if (current.aux % 2 == 0) {
              val patternCount = current.aux / 65536;
              for (patternIndex in 0..<patternCount) {
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
                        conditionNode.typeKind = subject.kind.value;
                        conditionNode.typeName = subject.name;
                        conditionNode.typePointee = subject.pointee;
                        semantic.nodes.data[conditionRoot] = conditionNode;
                    }
                } else {
                    if (condition.kind != TypeKind.Bool) {
                        semanticFail(
                            semantic, 6,
                            semantic.nodes.data[conditionRoot]);
                    }
                }
              }
            }
            checkBlock(semantic, bodyRoot);
            includeCurrentOwnership(
                semantic, ownershipMerged, ownershipCount);
        }
        restoreOwnership(semantic, ownershipMerged, ownershipCount);
        k_boot_free(ownershipMerged as unit*);
        k_boot_free(ownershipBefore as unit*);
        val exhaustive = enumWhenExhaustive(
            semantic, subject, roots, branchCount, false);
        if (subject.kind == TypeKind.Enum && !hasElse && !exhaustive) {
            semanticFail(semantic, 4, node);
        }
        k_boot_free(roots as unit*);
        return;
    }
    if (node.kind == AstKind.FunctionOrDefer) {
        val savedSuppressMoves = semantic.suppressMoves;
        semantic.suppressMoves = true;
        checkStatement(semantic, root - 1);
        semantic.suppressMoves = savedSuppressMoves;
        return;
    }
    if (node.kind == AstKind.BreakStatement) {
        if (semantic.loopDepth == 0) {
            semanticFail(semantic, 4, node);
        }
        return;
    }
    if (node.kind == AstKind.ContinueStatement) {
        if (semantic.loopDepth == 0) {
            semanticFail(semantic, 4, node);
        }
        return;
    }
    if (node.kind == AstKind.VariableDeclaration) {
        val initializerRoot = root - 1;
        var initializer = expressionType(semantic, initializerRoot);
        val nameNode = semantic.nodes.data[node.subtreeStart];
        val name = nodeHash(semantic, nameNode);
        if (localFindFrom(semantic.locals, name, semantic.scopeStart) !=
                semantic.locals.length) {
            semanticFail(semantic, 1, nameNode);
            return;
        }
        var valueType = initializer;
        if (valueType.kind == TypeKind.IntegerLiteral) {
            valueType = TypeValue(TypeKind.I32, 0, 0);
            var initializerNode = semantic.nodes.data[initializerRoot];
            initializerNode.typeKind = TypeKind.I32.value;
            semantic.nodes.data[initializerRoot] = initializerNode;
            resolveWhenResultType(semantic, initializerRoot, valueType);
            resolveIfResultType(semantic, initializerRoot, valueType);
        }
        val afterName = node.subtreeStart + 1;
        if (afterName < semantic.nodes.data[initializerRoot].subtreeStart) {
            valueType = typeFromNode(
                semantic,
                semantic.nodes.data[initializerRoot].subtreeStart - 1);
            initializer = contextualizeLiteralByteSlice(
                semantic, initializerRoot, valueType, initializer);
            if (!typeAccepts(valueType, initializer, semantic.genericArguments)) {
                semanticFail(
                    semantic, 4, semantic.nodes.data[initializerRoot]);
            }
            resolveWhenResultType(semantic, initializerRoot, valueType);
            resolveIfResultType(semantic, initializerRoot, valueType);
            if (initializer.kind == TypeKind.Array) {
                if (initializer.arrayElement().kind == TypeKind.Invalid) {
                    var initializerNode = semantic.nodes.data[initializerRoot];
                    initializerNode.typeKind = valueType.kind.value;
                    initializerNode.typeName = valueType.name;
                    initializerNode.typePointee = valueType.pointee;
                    semantic.nodes.data[initializerRoot] = initializerNode;
                }
            }
        }
        markExpressionMoved(semantic, initializerRoot);
        val automaticDrop =
            (valueType.kind == TypeKind.Struct || valueType.kind == TypeKind.String) &&
            typeNeedsOwnership(semantic, valueType);
        var declarationNode = semantic.nodes.data[root];
        if (automaticDrop) declarationNode.ownership = 2;
        semantic.nodes.data[root] = declarationNode;
        semantic.locals.add(LocalInfo(
            name, valueType, node.aux == TokenKind.KwVar.value, nameNode.start,
            false, automaticDrop));
        return;
    }
    if (node.kind == AstKind.ReturnStatement) {
        var actual = unitType();
        if (node.aux == 1) {
            actual = expressionType(semantic, root - 1);
            actual = contextualizeLiteralByteSlice(
                semantic, root - 1, semantic.returnType, actual);
        }
        val function = semantic.nodes.data[semantic.currentFunction];
        if (function.storage % 2 == 1 && node.aux == 1) {
            var statementLike = actual.kind == TypeKind.Unit;
            if (semantic.nodes.data[root - 1].kind == AstKind.Assignment)
                statementLike = true;
            if (statementLike) {
                if (semantic.returnType.kind != TypeKind.Unit)
                    semanticFail(semantic, 5, semantic.nodes.data[root - 1]);
                else {
                    var expressionStatement = node;
                    expressionStatement.kind = AstKind.ExpressionStatement;
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
                returnNode.typeKind = semantic.returnType.kind.value;
                returnNode.typeName = semantic.returnType.name;
                returnNode.typePointee = semantic.returnType.pointee;
                if (semantic.returnType.kind == TypeKind.Nullable) {
                    if (actual.kind == TypeKind.NullLiteral) {
                        returnNode.conversionKind = 2;
                    } else {
                        if (actual.kind != TypeKind.Nullable) {
                            returnNode.conversionKind = 1;
                        }
                    }
                }
                semantic.nodes.data[root] = returnNode;
                var valueNode = semantic.nodes.data[root - 1];
                if (valueNode.typeKind == TypeKind.IntegerLiteral.value) {
                    valueNode.typeKind = semantic.returnType.kind.value;
                    valueNode.typeName = semantic.returnType.name;
                    valueNode.typePointee = semantic.returnType.pointee;
                    semantic.nodes.data[root - 1] = valueNode;
                }
                resolveWhenResultType(
                    semantic, root - 1, semantic.returnType);
                resolveIfResultType(
                    semantic, root - 1, semantic.returnType);
                markExpressionMoved(semantic, root - 1);
            }
        }
        return;
    }
    if (node.kind == AstKind.ExpressionStatement) {
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
        val externCount = functionParameterCount(function);
        for (externPosition in 0..<externCount) {
            val externParameterRoot =
                functionParameterRoot(
                    semantic, root, externPosition + 1);
            typeFromNode(semantic, externParameterRoot - 1);
        }
        return;
    }
    semantic.locals.setLength(0);
    semantic.scopeStart = 0;
    semantic.returnType = functionReturnTypeValue(semantic, root);
    val count = functionParameterCount(function);
    for (position in 0..<count) {
        val parameterRoot =
            functionParameterRoot(semantic, root, position + 1);
        val parameter = semantic.nodes.data[parameterRoot];
        val nameNode = semantic.nodes.data[parameter.subtreeStart];
        val mutable = parameter.aux != 1;
        val parameterName = nodeHash(semantic, nameNode);
        if (localFindFrom(semantic.locals, parameterName, 0) !=
                semantic.locals.length) {
            semanticFail(semantic, 1, nameNode);
            return;
        }
        val parameterType = typeFromNode(semantic, parameterRoot - 1);
        var automaticDrop =
            parameter.aux == 0 && parameterType.kind == TypeKind.Struct &&
            typeNeedsOwnership(semantic, parameterType);
        val functionName = semantic.nodes.data[function.subtreeStart];
        if (function.conversionKind == 1 && position == 0 &&
            nodeHash(semantic, functionName) == 6385234055)
            automaticDrop = false;
        if (automaticDrop) {
            var parameterNode = semantic.nodes.data[parameterRoot];
            parameterNode.ownership = 2;
            semantic.nodes.data[parameterRoot] = parameterNode;
        }
        semantic.locals.add(
            LocalInfo(
                parameterName,
                parameterType,
                mutable,
                nameNode.start,
                false,
                automaticDrop)
        );
    }
    checkBlock(semantic, root - 1);
}

fn isConstantExpression(val semantic: Semantic, root: u64): bool {
    val node = semantic.nodes.data[root];
    if (node.kind == AstKind.Literal) return true;
    if (node.kind == AstKind.Identifier) {
        return declarationFind(semantic.constants, nodeHash(semantic, node)) !=
            semantic.constants.length;
    }
    if (node.kind == AstKind.Unary)
        return isConstantExpression(semantic, root - 1);
    if (node.kind == AstKind.Binary) {
        val rightRoot = root - 1;
        val leftRoot = semantic.nodes.data[rightRoot].subtreeStart - 1;
        return isConstantExpression(semantic, leftRoot) &&
            isConstantExpression(semantic, rightRoot);
    }
    if (node.kind == AstKind.Cast) {
        val typeRoot = root - 1;
        return isConstantExpression(
            semantic, semantic.nodes.data[typeRoot].subtreeStart - 1);
    }
    if (node.kind == AstKind.ArrayLiteral) {
        var childRoot = root - 1;
        for (index in 0..<node.aux) {
            if (!isConstantExpression(semantic, childRoot)) return false;
            childRoot = semantic.nodes.data[childRoot].subtreeStart - 1;
        }
        return true;
    }
    return false;
}

fn predeclareEnums(var semantic: Semantic, roots: u64*, count: u32) {
    for (index in 0..<count) {
        val root = roots[index as u64];
        val declaration = semantic.nodes.data[root];
        if (declaration.kind == AstKind.EnumDeclaration) {
            val nameNode = semantic.nodes.data[declaration.subtreeStart];
            val name = nodeHash(semantic, nameNode);
            if (declarationFind(semantic.enums, name) != semantic.enums.length) {
                semanticFail(semantic, 1, nameNode);
            } else {
                semantic.enums.add(DeclarationInfo(name, root));
                var backing = TypeValue(TypeKind.U32, 0, 0);
                if (declaration.storage > 0) {
                    backing = typeFromNode(
                        semantic, enumVariantStart(declaration) - 1);
                    if (!backing.isInteger()) {
                        semanticFail(
                            semantic, 4,
                            semantic.nodes.data[enumVariantStart(declaration) - 1]);
                        backing = TypeValue(TypeKind.U32, 0, 0);
                    }
                }
                var typed = declaration;
                typed.typePointee = backing.kind.value;
                semantic.nodes.data[root] = typed;
            }
        }
    }
}

fn collectDeclarations(var semantic: Semantic, programRoot: u64) {
    val program = semantic.nodes.data[programRoot];
    val roots =
        k_boot_alloc((program.aux as u64) * sizeof(u64)) as u64*;
    var root = programRoot - 1;
    for (index in program.aux>..0) {
        roots[index as u64] = root;
        root = semantic.nodes.data[root].subtreeStart - 1;
    }
    predeclareEnums(semantic, roots, program.aux);
    for (index in 0..<program.aux) {
        root = roots[index as u64];
        val declaration = semantic.nodes.data[root];
        if (declaration.kind == AstKind.StructDeclaration) {
            val nameNode = semantic.nodes.data[declaration.subtreeStart];
            val name = nodeHash(semantic, nameNode);
            if (declarationFind(semantic.structs, name) !=
                    semantic.structs.length ||
                declarationFind(semantic.enums, name) != semantic.enums.length) {
                semanticFail(semantic, 1, nameNode);
            } else {
                semantic.structs.add(DeclarationInfo(name, root));
            }
            var methodRoot = root - 1;
            val methods = structMethodCount(declaration);
            for (methodIndex in 0..<methods) {
                val method = semantic.nodes.data[methodRoot];
                val methodNameNode = semantic.nodes.data[method.subtreeStart];
                val methodName = methodHash(name, nodeHash(semantic, methodNameNode));
                if (functionTypeParameterCount(method) != 0) {
                    semanticFail(semantic, 4, methodNameNode);
                } else {
                    if (method.conversionKind == 1) {
                        val receiverRoot = functionParameterRoot(semantic, methodRoot, 1);
                        val receiver = semantic.nodes.data[receiverRoot];
                        val receiverName = semantic.nodes.data[receiver.subtreeStart];
                        if (nodeHash(semantic, receiverName) != 6385687311) {
                            semanticFail(semantic, 4, receiverName);
                        } else {
                            semantic.functions.add(DeclarationInfo(methodName, methodRoot));
                        }
                    } else if (method.conversionKind == 2) {
                        semantic.functions.add(DeclarationInfo(methodName, methodRoot));
                    } else {
                        semanticFail(semantic, 4, methodNameNode);
                    }
                }
                methodRoot = method.subtreeStart - 1;
            }
            var fieldRoot = rootBeforeStructMethods(semantic.nodes, root);
            val fields = structFieldCount(declaration);
            val savedStruct = semantic.currentStruct;
            semantic.currentStruct = root;
            for (fieldIndex in 0..<fields) {
                typeFromNode(semantic, fieldRoot - 1);
                fieldRoot =
                    semantic.nodes.data[fieldRoot].subtreeStart - 1;
            }
            semantic.currentStruct = savedStruct;
        } else {
            if (declaration.kind == AstKind.ConstantDeclaration) {
                val nameNode = semantic.nodes.data[declaration.subtreeStart];
                val name = nodeHash(semantic, nameNode);
                val initializerRoot = root - 1;
                var actual = expressionType(semantic, initializerRoot);
                if (declaration.aux == 0) {
                    if (actual.kind == TypeKind.Array) {
                        if (actual.arrayElement().kind == TypeKind.Invalid)
                            semanticFail(semantic, 4, semantic.nodes.data[initializerRoot]);
                    }
                }
                if (!isConstantExpression(semantic, initializerRoot))
                    semanticFail(semantic, 4, semantic.nodes.data[initializerRoot]);
                if (declaration.aux == 1) {
                    val expected = typeFromNode(
                        semantic, semantic.nodes.data[initializerRoot].subtreeStart - 1);
                    actual = contextualizeLiteralByteSlice(
                        semantic, initializerRoot, expected, actual);
                    val typeNode = semantic.nodes.data[
                        semantic.nodes.data[initializerRoot].subtreeStart - 1];
                    var accepted = typeAccepts(
                        expected, actual, semantic.genericArguments);
                    if (expected.kind == TypeKind.Array &&
                        typeNode.kind == AstKind.ArrayType &&
                        typeNode.aux == 0 && actual.kind == TypeKind.Array) {
                        accepted = typeAccepts(
                            expected.arrayElement(), actual.arrayElement(),
                            semantic.genericArguments);
                    }
                    if (!accepted)
                        semanticFail(semantic, 4, semantic.nodes.data[initializerRoot]);
                    if (expected.kind == TypeKind.Array &&
                        typeNode.kind == AstKind.ArrayType &&
                        typeNode.aux == 0 && actual.kind == TypeKind.Array) {
                        actual = expected.arrayElement().array(actual.arraySize());
                    } else actual = expected;
                }
                var typed = declaration;
                typed.typeKind = actual.kind.value;
                typed.typeName = actual.name;
                typed.typePointee = actual.pointee;
                semantic.nodes.data[root] = typed;
                semantic.constants.add(DeclarationInfo(name, root));
            } else if (declaration.kind == AstKind.EnumDeclaration) {
                val backing = TypeValue(
                    typeKindFromValue(declaration.typePointee), 0, 0);
                var nextNegative = false;
                var nextMagnitude: u64 = 0;
                var nextOverflow = false;
                for (left in 0..<declaration.aux) {
                    val leftRoot = enumVariantStart(declaration) + left as u64;
                    var leftNode = semantic.nodes.data[leftRoot];
                    var constant = IntegerConstant(
                        true, nextNegative, nextOverflow, nextMagnitude);
                    if (leftNode.conversionKind == 1)
                        constant = enumExplicitConstant(semantic, leftNode);
                    if (!constant.ok || !integerConstantFits(constant, backing))
                        semanticFail(semantic, 4, leftNode);
                    var value = constant.magnitude;
                    if (constant.negative) value = 0 - value;
                    for (prior in 0..<left) {
                        val priorNode = semantic.nodes.data[
                            enumVariantStart(declaration) + prior as u64];
                        if (priorNode.storage == value)
                            semanticFail(semantic, 1, leftNode);
                    }
                    leftNode.storage = value;
                    leftNode.conversionKind = left;
                    semantic.nodes.data[leftRoot] = leftNode;
                    nextNegative = constant.negative;
                    nextMagnitude = constant.magnitude;
                    nextOverflow = constant.overflow;
                    if (nextNegative) {
                        if (nextMagnitude > 0) nextMagnitude--;
                        if (nextMagnitude == 0) nextNegative = false;
                    } else {
                        if (nextMagnitude == 18446744073709551615) {
                            nextOverflow = true;
                        } else nextMagnitude++;
                    }
                    for (right in left + 1..<declaration.aux) {
                        val leftNode = semantic.nodes.data[
                            enumVariantStart(declaration) + left as u64];
                        val rightNode = semantic.nodes.data[
                            enumVariantStart(declaration) + right as u64];
                        if (nodeHash(semantic, leftNode) == nodeHash(semantic, rightNode)) {
                            semanticFail(semantic, 1, rightNode);
                        }
                    }
                }
            } else if (declaration.kind == AstKind.FunctionOrDefer) {
                val nameNode = semantic.nodes.data[declaration.subtreeStart];
                val name = nodeHash(semantic, nameNode);
                if (declarationFind(semantic.functions, name) !=
                        semantic.functions.length) {
                    semanticFail(semantic, 1, nameNode);
                } else {
                    semantic.functions.add(DeclarationInfo(name, root));
                }
            }
        }
    }
    k_boot_free(roots as unit*);
}

fn analyze(source: Source, val nodes: List<AstNode>): SemanticResult {
    val genericArguments = List<TypeValue>.new();
    val nodesLength = nodes.length;
    var semantic = Semantic(
        source, nodes,
        List<DeclarationInfo>.new(),
        List<DeclarationInfo>.new(),
        List<DeclarationInfo>.new(),
        List<DeclarationInfo>.new(),
        List<LocalInfo>.new(), genericArguments,
        semanticSuccess(), unitType(), 0,
        nodesLength, nodesLength, 0, nodesLength, false
    );
    defer semantic.free();
    val programRoot = semantic.nodes.length - 1;
    collectDeclarations(semantic, programRoot);
    if (semantic.result.ok) {
        val program = semantic.nodes.data[programRoot];
        var root = programRoot - 1;
        for (index in 0..<program.aux) {
            if (semantic.nodes.data[root].kind == AstKind.FunctionOrDefer) {
                checkFunction(semantic, root);
            } else {
                if (semantic.nodes.data[root].kind == AstKind.StructDeclaration) {
                    var methodRoot = root - 1;
                    val methods = structMethodCount(semantic.nodes.data[root]);
                    for (method in 0..<methods) {
                        val savedStruct = semantic.currentStruct;
                        semantic.currentStruct = root;
                        checkFunction(semantic, methodRoot);
                        semantic.currentStruct = savedStruct;
                        methodRoot = semantic.nodes.data[methodRoot].subtreeStart - 1;
                    }
                }
            }
            root = semantic.nodes.data[root].subtreeStart - 1;
        }
    }
    var result = semantic.result;
    result.genericArguments = semantic.genericArguments;

    return result;
}
