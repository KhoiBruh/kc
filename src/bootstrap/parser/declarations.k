module bootstrap.parser.declarations;

import bootstrap.token.Token;
import bootstrap.token.TokenKind;
import bootstrap.list.List;
import bootstrap.ast.AstKind;
import bootstrap.ast.AstNode;
import bootstrap.ast.ParameterMode;

fn parseFunction(
    var parser: Parser, isExtern: bool, start: u64,
    ownerStart: u64, ownerEnd: u64
): u64 {
    val subtreeStart = parser.nodes.length;
    if (!parser.expect(TokenKind.FN)) return 0;
    if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
    val functionName = parser.previous();
    parser.add(
        AstKind.NAME, functionName.start, functionName.end,
        parser.nodes.length, 0);
    var typeParameterCount: u32 = 0;
    if (parser.match(TokenKind.LESS)) {
        var typeParameters = true;
        while (typeParameters) {
            val parameterSubtree = parser.nodes.length;
            val parameterStart = parser.peek().start;
            if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
            val parameterName = parser.previous();
            parser.add(
                AstKind.NAME, parameterName.start, parameterName.end,
                parser.nodes.length, 0);
            var hasConstraint: u32 = 0;
            if (parser.match(TokenKind.COLON)) {
                if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
                val constraint = parser.previous();
                parser.add(
                    AstKind.NAME, constraint.start, constraint.end,
                    parser.nodes.length, 0);
                hasConstraint = 1;
            }
            parser.add(
                AstKind.TYPE_PARAMETER, parameterStart, parser.previous().end,
                parameterSubtree, hasConstraint);
            typeParameterCount++;
            if (!parser.match(TokenKind.COMMA)) {
                typeParameters = false;
            }
        }
        if (!parser.expect(TokenKind.GREATER)) return 0;
    }
    if (!parser.expect(TokenKind.LEFT_PAREN)) return 0;
    var parameterCount: u32 = 0;
    var associated: u32 = 0;
    if (ownerEnd != ownerStart) associated = 1;
    if (!parser.check(TokenKind.RIGHT_PAREN)) {
        var parameters = true;
        while (parameters) {
            val parameterSubtree = parser.nodes.length;
            val parameterStart = parser.peek().start;
            var mode = ParameterMode.OWNED;
            if (parser.match(TokenKind.VAL))
                mode = ParameterMode.IMMUTABLE_BORROW;
            else {
                if (parser.match(TokenKind.VAR))
                    mode = ParameterMode.MUTABLE_BORROW;
            }
            if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
            val parameterName = parser.previous();
            parser.add(
                AstKind.NAME, parameterName.start, parameterName.end,
                parser.nodes.length, 0);
            var typeNode: u64 = 0;
            if (ownerEnd != ownerStart && parameterCount == 0) {
                if (!parser.check(TokenKind.COLON)) {
                    associated = 0;
                    typeNode = parser.add(
                        AstKind.NAMED_TYPE, ownerStart, ownerEnd,
                        parser.nodes.length, 1);
                } else {
                    parser.current++;
                    typeNode = parseType(parser);
                }
            } else {
                if (!parser.expect(TokenKind.COLON)) return 0;
                typeNode = parseType(parser);
            }
            parser.add(
                AstKind.PARAMETER_OR_WHEN_BRANCH, parameterStart, parser.nodes.data[typeNode].end,
                parameterSubtree, mode.value);
            parameterCount++;
            if (!parser.match(TokenKind.COMMA)) parameters = false;
        }
    }
    if (!parser.expect(TokenKind.RIGHT_PAREN)) return 0;
    var infersReturn: u32 = 0;
    if (parser.match(TokenKind.COLON)) {
        parseType(parser);
    } else {
        parser.add(
            AstKind.NAMED_TYPE, parser.previous().end,
            parser.previous().end, parser.nodes.length, 49);
        if (parser.check(TokenKind.FAT_ARROW)) infersReturn = 1;
    }
    var end: u64 = 0;
    var expressionBody: u32 = 0;
    if (isExtern) {
        if (!parser.expect(TokenKind.SEMICOLON)) return 0;
        end = parser.previous().end;
    } else {
        if (parser.match(TokenKind.FAT_ARROW)) {
            expressionBody = 1;
            val bodyStart = parser.nodes.length;
            if (parser.check(TokenKind.IF) && !parser.arrowIfHasElseAhead()) {
                parseStatement(parser);
            } else {
                val expressionRoot = parseExpression(parser, 0);
                if (!parser.expect(TokenKind.SEMICOLON)) return 0;
                parser.add(
                    AstKind.RETURN_STATEMENT,
                    parser.nodes.data[expressionRoot].start,
                    parser.nodes.data[expressionRoot].end,
                    bodyStart, 1);
            }
            parser.add(AstKind.BLOCK, 0, 0, bodyStart, 1);
            end = parser.previous().end;
        } else {
        parseBlock(parser);
        end = parser.previous().end;
        }
    }
    var aux = parameterCount;
    if (isExtern) aux += 65536;
    aux += typeParameterCount * 131072;
    val root = parser.add(AstKind.FUNCTION_OR_DEFER, start, end, subtreeStart, aux);
    var function = parser.nodes.data[root];
    function.storage = (expressionBody + infersReturn * 2) as u64;
    if (ownerEnd > ownerStart) {
        function.conversionKind = 1 + associated;
    }
    parser.nodes.data[root] = function;
    return root;
}

fn parseStruct(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parser.peek().start;
    parser.current++;
    if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
    val structName = parser.previous();
    parser.add(
        AstKind.NAME, structName.start, structName.end,
        parser.nodes.length, 0);
    var typeParameterCount: u32 = 0;
    if (parser.match(TokenKind.LESS)) {
        var typeParameters = true;
        while (typeParameters) {
            val parameterSubtree = parser.nodes.length;
            val parameterStart = parser.peek().start;
            if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
            val parameterName = parser.previous();
            parser.add(
                AstKind.NAME, parameterName.start, parameterName.end,
                parser.nodes.length, 0);
            var hasConstraint: u32 = 0;
            if (parser.match(TokenKind.COLON)) {
                if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
                val constraint = parser.previous();
                parser.add(
                    AstKind.NAME, constraint.start, constraint.end,
                    parser.nodes.length, 0);
                hasConstraint = 1;
            }
            parser.add(
                AstKind.TYPE_PARAMETER, parameterStart, parser.previous().end,
                parameterSubtree, hasConstraint);
            typeParameterCount++;
            if (!parser.match(TokenKind.COMMA)) {
                typeParameters = false;
            }
        }
        if (!parser.expect(TokenKind.GREATER)) return 0;
    }
    if (!parser.expect(TokenKind.LEFT_PAREN)) return 0;
    var fieldCount: u32 = 0;
    if (!parser.check(TokenKind.RIGHT_PAREN)) {
        var fields = true;
        while (fields) {
            val fieldSubtree = parser.nodes.length;
            val fieldStart = parser.peek().start;
            if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
            val fieldName = parser.previous();
            parser.add(
                AstKind.NAME, fieldName.start, fieldName.end,
                parser.nodes.length, 0);
            if (!parser.expect(TokenKind.COLON)) return 0;
            val typeNode = parseType(parser);
            parser.add(
                AstKind.STRUCT_FIELD, fieldStart, parser.nodes.data[typeNode].end,
                fieldSubtree, 0);
            fieldCount++;
            if (!parser.match(TokenKind.COMMA)) fields = false;
        }
    }
    if (!parser.expect(TokenKind.RIGHT_PAREN)) return 0;
    var methodCount: u32 = 0;
    if (parser.match(TokenKind.LEFT_BRACE)) {
        while (!parser.check(TokenKind.RIGHT_BRACE)) {
            if (!parser.check(TokenKind.FN)) return 0;
            parseFunction(parser, false, parser.peek().start,
                structName.start, structName.end);
            methodCount++;
        }
        if (!parser.expect(TokenKind.RIGHT_BRACE)) return 0;
    }
    val root = parser.add(
        AstKind.STRUCT_DECLARATION, start, parser.previous().end,
        subtreeStart, fieldCount + typeParameterCount * 65536);
    var structure = parser.nodes.data[root];
    structure.storage = methodCount as u64;
    parser.nodes.data[root] = structure;
    return root;
}

fn parseEnum(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parser.peek().start;
    parser.current++;
    if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
    val name = parser.previous();
    parser.add(AstKind.NAME, name.start, name.end, parser.nodes.length, 0);
    var hasBacking: u64 = 0;
    if (parser.match(TokenKind.COLON)) {
        parseType(parser);
        hasBacking = parser.nodes.length - subtreeStart - 1;
    }
    if (!parser.expect(TokenKind.LEFT_BRACE)) return 0;
    if (parser.check(TokenKind.RIGHT_BRACE)) {
        parser.ok = false;
        return 0;
    }
    var count: u32 = 0;
    var parsing = true;
    while (parsing) {
        if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
        val variant = parser.previous();
        val variantRoot = parser.add(
            AstKind.NAME, variant.start, variant.end,
            parser.nodes.length, 0);
        if (parser.match(TokenKind.EQUAL)) {
            var negative: u32 = 0;
            if (parser.match(TokenKind.PLUS)) {
            } else if (parser.match(TokenKind.MINUS)) {
                negative = 1;
            }
            if (!parser.expect(TokenKind.INTEGER_LITERAL)) return 0;
            val value = parser.previous();
            var variantNode = parser.nodes.data[variantRoot];
            variantNode.conversionKind = 1;
            variantNode.storage = value.start;
            variantNode.typeName = value.end;
            variantNode.ownership = negative;
            parser.nodes.data[variantRoot] = variantNode;
        }
        count++;
        if (parser.match(TokenKind.COMMA)) {
            if (parser.check(TokenKind.RIGHT_BRACE)) {
                parser.ok = false;
                return 0;
            }
        } else {
            parsing = false;
        }
    }
    if (!parser.expect(TokenKind.RIGHT_BRACE)) return 0;
    val root = parser.add(
        AstKind.ENUM_DECLARATION, start, parser.previous().end,
        subtreeStart, count);
    var enumeration = parser.nodes.data[root];
    enumeration.storage = hasBacking;
    parser.nodes.data[root] = enumeration;
    return root;
}

fn parseModule(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parser.peek().start;
    parser.current++;
    if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
    val firstName = parser.previous();
    parser.add(
        AstKind.NAME, firstName.start, firstName.end,
        parser.nodes.length, 0);
    var partCount: u32 = 1;
    while (parser.match(TokenKind.DOT)) {
        if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
        val name = parser.previous();
        parser.add(
            AstKind.NAME, name.start, name.end,
            parser.nodes.length, 0);
        partCount++;
    }
    if (!parser.expect(TokenKind.SEMICOLON)) return 0;
    return parser.add(
        AstKind.MODULE_DECLARATION, start, parser.previous().end,
        subtreeStart, partCount);
}

fn parseImport(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parser.peek().start;
    parser.current++;
    if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
    val firstName = parser.previous();
    parser.add(
        AstKind.NAME, firstName.start, firstName.end,
        parser.nodes.length, 0);
    var partCount: u32 = 1;
    var isWildcard: u32 = 0;
    while (parser.match(TokenKind.DOT)) {
        if (parser.match(TokenKind.STAR)) {
            isWildcard = 1;
            partCount++;
            break;
        }
        if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
        val name = parser.previous();
        parser.add(
            AstKind.NAME, name.start, name.end,
            parser.nodes.length, 0);
        partCount++;
    }
    if (!parser.expect(TokenKind.SEMICOLON)) return 0;
    return parser.add(
        AstKind.IMPORT_DECLARATION, start, parser.previous().end,
        subtreeStart, partCount + isWildcard * 65536);
}

fn parseConstant(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parser.peek().start;
    parser.current++;
    if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
    val name = parser.previous();
    parser.add(AstKind.NAME, name.start, name.end, parser.nodes.length, 0);
    var hasType: u32 = 0;
    if (parser.match(TokenKind.COLON)) { parseType(parser); hasType = 1; }
    if (!parser.expect(TokenKind.EQUAL)) return 0;
    parseExpression(parser, 0);
    if (!parser.expect(TokenKind.SEMICOLON)) return 0;
    return parser.add(
        AstKind.CONSTANT_DECLARATION, start,
        parser.previous().end, subtreeStart, hasType);
}
