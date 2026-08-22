module bootstrap.semantic.declarations;

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

fn inferFunctionReturn(var semantic: Semantic, functionRoot: u64): TypeValue {
    var function = semantic.nodes.data[functionRoot];
    if ((function.storage / 8) % 2 == 1)
        return TypeValue(typeKindFromValue(function.typeKind), function.typeName, function.typePointee);
    if ((function.storage / 4) % 2 == 1) {
        semantic.fail(4, function);
        return invalidType();
    }
    function.storage = function.storage + 4;
    semantic.nodes.data[functionRoot] = function;
    val savedLength = semantic.locals.length;
    val savedScope = semantic.scopeStart;
    val savedFunction = semantic.currentFunction;
    val savedReturn = semantic.returnType;
    semantic.currentFunction = functionRoot;
    for (position in 0..<function.parameterCount()) {
        val parameterRoot = functionParameterRoot(semantic, functionRoot, position + 1);
        val parameter = semantic.nodes.data[parameterRoot];
        val nameNode = semantic.nodes.data[parameter.subtreeStart];
        semantic.locals.add(
            LocalInfo(
                semantic.hash(nameNode),
                typeFromNode(semantic, parameterRoot - 1),
                parameter.mode() != ParameterMode.ImmutableBorrow,
                nameNode.start, false, false
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
    
    return if (function.infersReturn())
            inferFunctionReturn(semantic, functionRoot)
        else typeFromNode(semantic, functionReturnRoot(semantic, functionRoot));
}

fn functionTypeParameterRoot(val semantic: Semantic, functionRoot: u64, position: u32): u64 {
    val function = semantic.nodes.data[functionRoot];
    var root = functionReturnRoot(semantic, functionRoot);
    val parameters = function.parameterCount();
    for (parameter in 0..<parameters) {
        root = semantic.nodes.data[root].subtreeStart - 1;
    }
    val remaining = function.typeParameterCount();
    for (index in position - 1..<remaining) {
        root = semantic.nodes.data[root].subtreeStart - 1;
    }
    return root;
}

fn rootBeforeStructMethods(val nodes: List<AstNode>, structureRoot: u64): u64 {
    var root = structureRoot - 1;
    val remaining = nodes.data[structureRoot].methodCount();
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
        if (function.parameterCount() == 0) return semantic.nodes.length;
        val receiverType = semantic.nodes.data[
            functionParameterRoot(semantic, functionRoot, 1) - 1];
        val structure = declarationFind(
            semantic.structs, semantic.hash(receiverType));
        if (structure == semantic.structs.length) return semantic.nodes.length;
        return semantic.structs.data[structure].node;
    }
    if (function.conversionKind != 2) return semantic.nodes.length;
    for (structureIndex in 0..<semantic.structs.length) {
        val structureRoot = semantic.structs.data[structureIndex].node;
        var methodRoot = structureRoot - 1;
        val methodCount = semantic.nodes.data[structureRoot].methodCount();
        for (methodIndex in 0..<methodCount) {
            if (methodRoot == functionRoot) return structureRoot;
            methodRoot = semantic.nodes.data[methodRoot].subtreeStart - 1;
        }
    }
    return semantic.nodes.length;
}

fn fieldRootAt(val nodes: List<AstNode>, structureRoot: u64, wanted: u32): u64 {
    val structure = nodes.data[structureRoot];
    var roots = k_boot_alloc((structure.fieldCount() as u64) * sizeof(u64)) as u64*;
    var root = rootBeforeStructMethods(nodes, structureRoot);
    val remaining = structure.fieldCount();
    for (index in remaining>..0) {
        roots[index as u64] = root;
        root = nodes.data[root].subtreeStart - 1;
    }
    val result = roots[wanted as u64];
    k_boot_free(roots as unit*);
    return result;
}

fn functionReturnRoot(val semantic: Semantic, functionRoot: u64): u64 {
    val function = semantic.nodes.data[functionRoot];
    if (function.isExtern()) return functionRoot - 1;
    val body = semantic.nodes.data[functionRoot - 1];
    return body.subtreeStart - 1;
}

fn functionParameterRoot(
    val semantic: Semantic, functionRoot: u64, position: u32): u64 {
    val function = semantic.nodes.data[functionRoot];
    var root = functionReturnRoot(semantic, functionRoot);
    val remaining = function.parameterCount();
    for (index in position - 1..<remaining) {
        root = semantic.nodes.data[root].subtreeStart - 1;
    }
    return root;
}

fn checkFunction(var semantic: Semantic, root: u64) {
    val function = semantic.nodes.data[root];
    semantic.currentFunction = root;
    if (function.isExtern()) {
        typeFromNode(semantic, functionReturnRoot(semantic, root));
        val externCount = function.parameterCount();
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
    val count = function.parameterCount();
    for (position in 0..<count) {
        val parameterRoot =
            functionParameterRoot(semantic, root, position + 1);
        val parameter = semantic.nodes.data[parameterRoot];
        val nameNode = semantic.nodes.data[parameter.subtreeStart];
        val mutable =
            parameter.mode() != ParameterMode.ImmutableBorrow;
        val parameterName = semantic.hash(nameNode);
        if (localFindFrom(semantic.locals, parameterName, 0) !=
                semantic.locals.length) {
            semantic.fail(1, nameNode);
            return;
        }
        val parameterType = typeFromNode(semantic, parameterRoot - 1);
        var automaticDrop =
            parameter.mode() == ParameterMode.Owned &&
            parameterType.kind == TypeKind.Struct &&
            typeNeedsOwnership(semantic, parameterType);
        val functionName = semantic.nodes.data[function.subtreeStart];
        if (function.conversionKind == 1 && position == 0 &&
            semantic.hash(functionName) == 6385234055)
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
        return declarationFind(semantic.constants, semantic.hash(node)) !=
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
            val name = semantic.hash(nameNode);
            if (declarationFind(semantic.enums, name) != semantic.enums.length) {
                semantic.fail(1, nameNode);
            } else {
                semantic.enums.add(DeclarationInfo(name, root));
                var backing = TypeValue(TypeKind.U32, 0, 0);
                if (declaration.storage > 0) {
                    backing = typeFromNode(
                        semantic, enumVariantStart(declaration) - 1);
                    if (!backing.isInteger()) {
                        semantic.fail(
                            4,
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
            val name = semantic.hash(nameNode);
            if (declarationFind(semantic.structs, name) !=
                    semantic.structs.length ||
                declarationFind(semantic.enums, name) != semantic.enums.length) {
                semantic.fail(1, nameNode);
            } else {
                semantic.structs.add(DeclarationInfo(name, root));
            }
            var methodRoot = root - 1;
            val methods = declaration.methodCount();
            for (methodIndex in 0..<methods) {
                val method = semantic.nodes.data[methodRoot];
                val methodNameNode = semantic.nodes.data[method.subtreeStart];
                val methodName = methodHash(name, semantic.hash(methodNameNode));
                if (method.typeParameterCount() != 0) {
                    semantic.fail(4, methodNameNode);
                } else {
                    if (method.conversionKind == 1) {
                        val receiverRoot = functionParameterRoot(semantic, methodRoot, 1);
                        val receiver = semantic.nodes.data[receiverRoot];
                        val receiverName = semantic.nodes.data[receiver.subtreeStart];
                        if (semantic.hash(receiverName) != 6385687311) {
                            semantic.fail(4, receiverName);
                        } else {
                            semantic.functions.add(DeclarationInfo(methodName, methodRoot));
                        }
                    } else if (method.conversionKind == 2) {
                        semantic.functions.add(DeclarationInfo(methodName, methodRoot));
                    } else {
                        semantic.fail(4, methodNameNode);
                    }
                }
                methodRoot = method.subtreeStart - 1;
            }
            var fieldRoot = rootBeforeStructMethods(semantic.nodes, root);
            val fields = declaration.fieldCount();
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
                val name = semantic.hash(nameNode);
                val initializerRoot = root - 1;
                var actual = expressionType(semantic, initializerRoot);
                if (declaration.aux == 0) {
                    if (actual.kind == TypeKind.Array) {
                        if (actual.arrayElement().kind == TypeKind.Invalid)
                            semantic.fail(4, semantic.nodes.data[initializerRoot]);
                    }
                }
                if (!isConstantExpression(semantic, initializerRoot))
                    semantic.fail(4, semantic.nodes.data[initializerRoot]);
                if (declaration.aux == 1) {
                    val expected = typeFromNode(
                        semantic, semantic.nodes.data[initializerRoot].subtreeStart - 1);
                    actual = contextualizeLiteralByteSlice(
                        semantic, initializerRoot, expected, actual);
                    val typeNode = semantic.nodes.data[
                        semantic.nodes.data[initializerRoot].subtreeStart - 1];
                    var accepted = expected.accepts(
                        actual, semantic.genericArguments);
                    if (expected.kind == TypeKind.Array &&
                        typeNode.kind == AstKind.ArrayType &&
                        typeNode.aux == 0 && actual.kind == TypeKind.Array) {
                        accepted = expected.arrayElement().accepts(
                            actual.arrayElement(), semantic.genericArguments);
                    }
                    if (!accepted)
                        semantic.fail(4, semantic.nodes.data[initializerRoot]);
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
                        semantic.fail(4, leftNode);
                    var value = constant.magnitude;
                    if (constant.negative) value = 0 - value;
                    for (prior in 0..<left) {
                        val priorNode = semantic.nodes.data[
                            enumVariantStart(declaration) + prior as u64];
                        if (priorNode.storage == value)
                            semantic.fail(1, leftNode);
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
                        if (semantic.hash(leftNode) == semantic.hash(rightNode)) {
                            semantic.fail(1, rightNode);
                        }
                    }
                }
            } else if (declaration.kind == AstKind.FunctionOrDefer) {
                val nameNode = semantic.nodes.data[declaration.subtreeStart];
                val name = semantic.hash(nameNode);
                if (declarationFind(semantic.functions, name) !=
                        semantic.functions.length) {
                    semantic.fail(1, nameNode);
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
                    val methods = semantic.nodes.data[root].methodCount();
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
