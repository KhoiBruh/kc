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
    if (!parser.expect(TokenKind.KwFn)) return 0;
    if (!parser.expect(TokenKind.Identifier)) return 0;
    val functionName = parser.previous();
    parser.add(
        AstKind.Name, functionName.start, functionName.end,
        parser.nodes.length, 0);
    var typeParameterCount: u32 = 0;
    if (parser.match(TokenKind.Less)) {
        var typeParameters = true;
        while (typeParameters) {
            val parameterSubtree = parser.nodes.length;
            val parameterStart = parser.peek().start;
            if (!parser.expect(TokenKind.Identifier)) return 0;
            val parameterName = parser.previous();
            parser.add(
                AstKind.Name, parameterName.start, parameterName.end,
                parser.nodes.length, 0);
            var hasConstraint: u32 = 0;
            if (parser.match(TokenKind.Colon)) {
                if (!parser.expect(TokenKind.Identifier)) return 0;
                val constraint = parser.previous();
                parser.add(
                    AstKind.Name, constraint.start, constraint.end,
                    parser.nodes.length, 0);
                hasConstraint = 1;
            }
            parser.add(
                AstKind.TypeParameter, parameterStart, parser.previous().end,
                parameterSubtree, hasConstraint);
            typeParameterCount++;
            if (!parser.match(TokenKind.Comma)) {
                typeParameters = false;
            }
        }
        if (!parser.expect(TokenKind.Greater)) return 0;
    }
    if (!parser.expect(TokenKind.LeftParen)) return 0;
    var parameterCount: u32 = 0;
    var associated: u32 = 0;
    if (ownerEnd != ownerStart) associated = 1;
    if (!parser.check(TokenKind.RightParen)) {
        var parameters = true;
        while (parameters) {
            val parameterSubtree = parser.nodes.length;
            val parameterStart = parser.peek().start;
            var mode = ParameterMode.Owned;
            if (parser.match(TokenKind.KwVal))
                mode = ParameterMode.ImmutableBorrow;
            else {
                if (parser.match(TokenKind.KwVar))
                    mode = ParameterMode.MutableBorrow;
            }
            if (!parser.expect(TokenKind.Identifier)) return 0;
            val parameterName = parser.previous();
            parser.add(
                AstKind.Name, parameterName.start, parameterName.end,
                parser.nodes.length, 0);
            var typeNode: u64 = 0;
            if (ownerEnd != ownerStart && parameterCount == 0) {
                if (!parser.check(TokenKind.Colon)) {
                    associated = 0;
                    typeNode = parser.add(
                        AstKind.NamedType, ownerStart, ownerEnd,
                        parser.nodes.length, 1);
                } else {
                    parser.current++;
                    typeNode = parseType(parser);
                }
            } else {
                if (!parser.expect(TokenKind.Colon)) return 0;
                typeNode = parseType(parser);
            }
            parser.add(
                AstKind.ParameterOrWhenBranch, parameterStart, parser.nodes.data[typeNode].end,
                parameterSubtree, mode.value);
            parameterCount++;
            if (!parser.match(TokenKind.Comma)) parameters = false;
        }
    }
    if (!parser.expect(TokenKind.RightParen)) return 0;
    var infersReturn: u32 = 0;
    if (parser.match(TokenKind.Colon)) {
        parseType(parser);
    } else {
        parser.add(
            AstKind.NamedType, parser.previous().end,
            parser.previous().end, parser.nodes.length, 49);
        if (parser.check(TokenKind.FatArrow)) infersReturn = 1;
    }
    var end: u64 = 0;
    var expressionBody: u32 = 0;
    if (isExtern) {
        if (!parser.expect(TokenKind.Semicolon)) return 0;
        end = parser.previous().end;
    } else {
        if (parser.match(TokenKind.FatArrow)) {
            expressionBody = 1;
            val bodyStart = parser.nodes.length;
            if (parser.check(TokenKind.KwIf) && !parser.arrowIfHasElseAhead()) {
                parseStatement(parser);
            } else {
                val expressionRoot = parseExpression(parser, 0);
                if (!parser.expect(TokenKind.Semicolon)) return 0;
                parser.add(
                    AstKind.ReturnStatement,
                    parser.nodes.data[expressionRoot].start,
                    parser.nodes.data[expressionRoot].end,
                    bodyStart, 1);
            }
            parser.add(AstKind.Block, 0, 0, bodyStart, 1);
            end = parser.previous().end;
        } else {
        parseBlock(parser);
        end = parser.previous().end;
        }
    }
    var aux = parameterCount;
    if (isExtern) aux += 65536;
    aux += typeParameterCount * 131072;
    val root = parser.add(AstKind.FunctionOrDefer, start, end, subtreeStart, aux);
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
    if (!parser.expect(TokenKind.Identifier)) return 0;
    val structName = parser.previous();
    parser.add(
        AstKind.Name, structName.start, structName.end,
        parser.nodes.length, 0);
    var typeParameterCount: u32 = 0;
    if (parser.match(TokenKind.Less)) {
        var typeParameters = true;
        while (typeParameters) {
            val parameterSubtree = parser.nodes.length;
            val parameterStart = parser.peek().start;
            if (!parser.expect(TokenKind.Identifier)) return 0;
            val parameterName = parser.previous();
            parser.add(
                AstKind.Name, parameterName.start, parameterName.end,
                parser.nodes.length, 0);
            var hasConstraint: u32 = 0;
            if (parser.match(TokenKind.Colon)) {
                if (!parser.expect(TokenKind.Identifier)) return 0;
                val constraint = parser.previous();
                parser.add(
                    AstKind.Name, constraint.start, constraint.end,
                    parser.nodes.length, 0);
                hasConstraint = 1;
            }
            parser.add(
                AstKind.TypeParameter, parameterStart, parser.previous().end,
                parameterSubtree, hasConstraint);
            typeParameterCount++;
            if (!parser.match(TokenKind.Comma)) {
                typeParameters = false;
            }
        }
        if (!parser.expect(TokenKind.Greater)) return 0;
    }
    if (!parser.expect(TokenKind.LeftParen)) return 0;
    var fieldCount: u32 = 0;
    if (!parser.check(TokenKind.RightParen)) {
        var fields = true;
        while (fields) {
            val fieldSubtree = parser.nodes.length;
            val fieldStart = parser.peek().start;
            if (!parser.expect(TokenKind.Identifier)) return 0;
            val fieldName = parser.previous();
            parser.add(
                AstKind.Name, fieldName.start, fieldName.end,
                parser.nodes.length, 0);
            if (!parser.expect(TokenKind.Colon)) return 0;
            val typeNode = parseType(parser);
            parser.add(
                AstKind.StructField, fieldStart, parser.nodes.data[typeNode].end,
                fieldSubtree, 0);
            fieldCount++;
            if (!parser.match(TokenKind.Comma)) fields = false;
        }
    }
    if (!parser.expect(TokenKind.RightParen)) return 0;
    var methodCount: u32 = 0;
    if (parser.match(TokenKind.LeftBrace)) {
        while (!parser.check(TokenKind.RightBrace)) {
            if (!parser.check(TokenKind.KwFn)) return 0;
            parseFunction(parser, false, parser.peek().start,
                structName.start, structName.end);
            methodCount++;
        }
        if (!parser.expect(TokenKind.RightBrace)) return 0;
    }
    val root = parser.add(
        AstKind.StructDeclaration, start, parser.previous().end,
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
    if (!parser.expect(TokenKind.Identifier)) return 0;
    val name = parser.previous();
    parser.add(AstKind.Name, name.start, name.end, parser.nodes.length, 0);
    var hasBacking: u64 = 0;
    if (parser.match(TokenKind.Colon)) {
        parseType(parser);
        hasBacking = parser.nodes.length - subtreeStart - 1;
    }
    if (!parser.expect(TokenKind.LeftBrace)) return 0;
    if (parser.check(TokenKind.RightBrace)) {
        parser.ok = false;
        return 0;
    }
    var count: u32 = 0;
    var parsing = true;
    while (parsing) {
        if (!parser.expect(TokenKind.Identifier)) return 0;
        val variant = parser.previous();
        val variantRoot = parser.add(
            AstKind.Name, variant.start, variant.end,
            parser.nodes.length, 0);
        if (parser.match(TokenKind.Equal)) {
            var negative: u32 = 0;
            if (parser.match(TokenKind.Plus)) {
            } else if (parser.match(TokenKind.Minus)) {
                negative = 1;
            }
            if (!parser.expect(TokenKind.IntegerLiteral)) return 0;
            val value = parser.previous();
            var variantNode = parser.nodes.data[variantRoot];
            variantNode.conversionKind = 1;
            variantNode.storage = value.start;
            variantNode.typeName = value.end;
            variantNode.ownership = negative;
            parser.nodes.data[variantRoot] = variantNode;
        }
        count++;
        if (parser.match(TokenKind.Comma)) {
            if (parser.check(TokenKind.RightBrace)) {
                parser.ok = false;
                return 0;
            }
        } else {
            parsing = false;
        }
    }
    if (!parser.expect(TokenKind.RightBrace)) return 0;
    val root = parser.add(
        AstKind.EnumDeclaration, start, parser.previous().end,
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
    if (!parser.expect(TokenKind.Identifier)) return 0;
    val firstName = parser.previous();
    parser.add(
        AstKind.Name, firstName.start, firstName.end,
        parser.nodes.length, 0);
    var partCount: u32 = 1;
    while (parser.match(TokenKind.Dot)) {
        if (!parser.expect(TokenKind.Identifier)) return 0;
        val name = parser.previous();
        parser.add(
            AstKind.Name, name.start, name.end,
            parser.nodes.length, 0);
        partCount++;
    }
    if (!parser.expect(TokenKind.Semicolon)) return 0;
    return parser.add(
        AstKind.ModuleDeclaration, start, parser.previous().end,
        subtreeStart, partCount);
}

fn parseImport(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parser.peek().start;
    parser.current++;
    if (!parser.expect(TokenKind.Identifier)) return 0;
    val firstName = parser.previous();
    parser.add(
        AstKind.Name, firstName.start, firstName.end,
        parser.nodes.length, 0);
    var partCount: u32 = 1;
    var isWildcard: u32 = 0;
    while (parser.match(TokenKind.Dot)) {
        if (parser.match(TokenKind.Star)) {
            isWildcard = 1;
            partCount++;
            break;
        }
        if (!parser.expect(TokenKind.Identifier)) return 0;
        val name = parser.previous();
        parser.add(
            AstKind.Name, name.start, name.end,
            parser.nodes.length, 0);
        partCount++;
    }
    if (!parser.expect(TokenKind.Semicolon)) return 0;
    return parser.add(
        AstKind.ImportDeclaration, start, parser.previous().end,
        subtreeStart, partCount + isWildcard * 65536);
}

fn parseConstant(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parser.peek().start;
    parser.current++;
    if (!parser.expect(TokenKind.Identifier)) return 0;
    val name = parser.previous();
    parser.add(AstKind.Name, name.start, name.end, parser.nodes.length, 0);
    var hasType: u32 = 0;
    if (parser.match(TokenKind.Colon)) { parseType(parser); hasType = 1; }
    if (!parser.expect(TokenKind.Equal)) return 0;
    parseExpression(parser, 0);
    if (!parser.expect(TokenKind.Semicolon)) return 0;
    return parser.add(
        AstKind.ConstantDeclaration, start,
        parser.previous().end, subtreeStart, hasType);
}
