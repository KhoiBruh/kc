module bootstrap.parser.declarations;

import bootstrap.token.Token;
import bootstrap.token.TokenKind;
import bootstrap.list.List;
import bootstrap.ast.AstKind;
import bootstrap.ast.AstNode;
import bootstrap.ast.ParameterMode;

fn arrowIfHasElseAhead(parser: Parser): bool {
    for (cursor in parser.current..<parser.tokens.length) {
        val kind = parser.tokens.data[cursor].kind;
        if (kind == TokenKind.KwElse) return true;
        var declaration = kind == TokenKind.EndOfFile;
        if (kind == TokenKind.KwConst) declaration = true;
        if (kind == TokenKind.KwExtern) declaration = true;
        if (kind == TokenKind.KwFn) declaration = true;
        if (kind == TokenKind.KwStruct) declaration = true;
        if (kind == TokenKind.KwEnum) declaration = true;
        if (declaration) return false;
    }
    return false;
}

fn parseFunction(
    var parser: Parser, isExtern: bool, start: u64,
    ownerStart: u64, ownerEnd: u64
): u64 {
    val subtreeStart = parser.nodes.length;
    if (!parserExpect(parser, TokenKind.KwFn)) return 0;
    if (!parserExpect(parser, TokenKind.Identifier)) return 0;
    val functionName = parserPrevious(parser);
    parserAdd(
        parser, AstKind.Name, functionName.start, functionName.end,
        parser.nodes.length, 0);
    var typeParameterCount: u32 = 0;
    if (parserMatch(parser, TokenKind.Less)) {
        var typeParameters = true;
        while (typeParameters) {
            val parameterSubtree = parser.nodes.length;
            val parameterStart = parserPeek(parser).start;
            if (!parserExpect(parser, TokenKind.Identifier)) return 0;
            val parameterName = parserPrevious(parser);
            parserAdd(
                parser, AstKind.Name, parameterName.start, parameterName.end,
                parser.nodes.length, 0);
            var hasConstraint: u32 = 0;
            if (parserMatch(parser, TokenKind.Colon)) {
                if (!parserExpect(parser, TokenKind.Identifier)) return 0;
                val constraint = parserPrevious(parser);
                parserAdd(
                    parser, AstKind.Name, constraint.start, constraint.end,
                    parser.nodes.length, 0);
                hasConstraint = 1;
            }
            parserAdd(
                parser, AstKind.TypeParameter, parameterStart, parserPrevious(parser).end,
                parameterSubtree, hasConstraint);
            typeParameterCount++;
            if (!parserMatch(parser, TokenKind.Comma)) {
                typeParameters = false;
            }
        }
        if (!parserExpect(parser, TokenKind.Greater)) return 0;
    }
    if (!parserExpect(parser, TokenKind.LeftParen)) return 0;
    var parameterCount: u32 = 0;
    var associated: u32 = 0;
    if (ownerEnd != ownerStart) associated = 1;
    if (!parserCheck(parser, TokenKind.RightParen)) {
        var parameters = true;
        while (parameters) {
            val parameterSubtree = parser.nodes.length;
            val parameterStart = parserPeek(parser).start;
            var mode = ParameterMode.Owned;
            if (parserMatch(parser, TokenKind.KwVal))
                mode = ParameterMode.ImmutableBorrow;
            else {
                if (parserMatch(parser, TokenKind.KwVar))
                    mode = ParameterMode.MutableBorrow;
            }
            if (!parserExpect(parser, TokenKind.Identifier)) return 0;
            val parameterName = parserPrevious(parser);
            parserAdd(
                parser, AstKind.Name, parameterName.start, parameterName.end,
                parser.nodes.length, 0);
            var typeNode: u64 = 0;
            if (ownerEnd != ownerStart && parameterCount == 0) {
                if (!parserCheck(parser, TokenKind.Colon)) {
                    associated = 0;
                    typeNode = parserAdd(
                        parser, AstKind.NamedType, ownerStart, ownerEnd,
                        parser.nodes.length, 1);
                } else {
                    parser.current++;
                    typeNode = parseType(parser);
                }
            } else {
                if (!parserExpect(parser, TokenKind.Colon)) return 0;
                typeNode = parseType(parser);
            }
            parserAdd(
                parser, AstKind.ParameterOrWhenBranch, parameterStart, parser.nodes.data[typeNode].end,
                parameterSubtree, mode.value);
            parameterCount++;
            if (!parserMatch(parser, TokenKind.Comma)) parameters = false;
        }
    }
    if (!parserExpect(parser, TokenKind.RightParen)) return 0;
    var infersReturn: u32 = 0;
    if (parserMatch(parser, TokenKind.Colon)) {
        parseType(parser);
    } else {
        parserAdd(
            parser, AstKind.NamedType, parserPrevious(parser).end,
            parserPrevious(parser).end, parser.nodes.length, 49);
        if (parserCheck(parser, TokenKind.FatArrow)) infersReturn = 1;
    }
    var end: u64 = 0;
    var expressionBody: u32 = 0;
    if (isExtern) {
        if (!parserExpect(parser, TokenKind.Semicolon)) return 0;
        end = parserPrevious(parser).end;
    } else {
        if (parserMatch(parser, TokenKind.FatArrow)) {
            expressionBody = 1;
            val bodyStart = parser.nodes.length;
            if (parserCheck(parser, TokenKind.KwIf) && !arrowIfHasElseAhead(parser)) {
                parseStatement(parser);
            } else {
                val expressionRoot = parseExpression(parser, 0);
                if (!parserExpect(parser, TokenKind.Semicolon)) return 0;
                parserAdd(
                    parser, AstKind.ReturnStatement,
                    parser.nodes.data[expressionRoot].start,
                    parser.nodes.data[expressionRoot].end,
                    bodyStart, 1);
            }
            parserAdd(parser, AstKind.Block, 0, 0, bodyStart, 1);
            end = parserPrevious(parser).end;
        } else {
        parseBlock(parser);
        end = parserPrevious(parser).end;
        }
    }
    var aux = parameterCount;
    if (isExtern) aux += 65536;
    aux += typeParameterCount * 131072;
    val root = parserAdd(parser, AstKind.FunctionOrDefer, start, end, subtreeStart, aux);
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
    val start = parserPeek(parser).start;
    parser.current++;
    if (!parserExpect(parser, TokenKind.Identifier)) return 0;
    val structName = parserPrevious(parser);
    parserAdd(
        parser, AstKind.Name, structName.start, structName.end,
        parser.nodes.length, 0);
    var typeParameterCount: u32 = 0;
    if (parserMatch(parser, TokenKind.Less)) {
        var typeParameters = true;
        while (typeParameters) {
            val parameterSubtree = parser.nodes.length;
            val parameterStart = parserPeek(parser).start;
            if (!parserExpect(parser, TokenKind.Identifier)) return 0;
            val parameterName = parserPrevious(parser);
            parserAdd(
                parser, AstKind.Name, parameterName.start, parameterName.end,
                parser.nodes.length, 0);
            var hasConstraint: u32 = 0;
            if (parserMatch(parser, TokenKind.Colon)) {
                if (!parserExpect(parser, TokenKind.Identifier)) return 0;
                val constraint = parserPrevious(parser);
                parserAdd(
                    parser, AstKind.Name, constraint.start, constraint.end,
                    parser.nodes.length, 0);
                hasConstraint = 1;
            }
            parserAdd(
                parser, AstKind.TypeParameter, parameterStart, parserPrevious(parser).end,
                parameterSubtree, hasConstraint);
            typeParameterCount++;
            if (!parserMatch(parser, TokenKind.Comma)) {
                typeParameters = false;
            }
        }
        if (!parserExpect(parser, TokenKind.Greater)) return 0;
    }
    if (!parserExpect(parser, TokenKind.LeftParen)) return 0;
    var fieldCount: u32 = 0;
    if (!parserCheck(parser, TokenKind.RightParen)) {
        var fields = true;
        while (fields) {
            val fieldSubtree = parser.nodes.length;
            val fieldStart = parserPeek(parser).start;
            if (!parserExpect(parser, TokenKind.Identifier)) return 0;
            val fieldName = parserPrevious(parser);
            parserAdd(
                parser, AstKind.Name, fieldName.start, fieldName.end,
                parser.nodes.length, 0);
            if (!parserExpect(parser, TokenKind.Colon)) return 0;
            val typeNode = parseType(parser);
            parserAdd(
                parser, AstKind.StructField, fieldStart, parser.nodes.data[typeNode].end,
                fieldSubtree, 0);
            fieldCount++;
            if (!parserMatch(parser, TokenKind.Comma)) fields = false;
        }
    }
    if (!parserExpect(parser, TokenKind.RightParen)) return 0;
    var methodCount: u32 = 0;
    if (parserMatch(parser, TokenKind.LeftBrace)) {
        while (!parserCheck(parser, TokenKind.RightBrace)) {
            if (!parserCheck(parser, TokenKind.KwFn)) return 0;
            parseFunction(parser, false, parserPeek(parser).start,
                structName.start, structName.end);
            methodCount++;
        }
        if (!parserExpect(parser, TokenKind.RightBrace)) return 0;
    }
    val root = parserAdd(
        parser, AstKind.StructDeclaration, start, parserPrevious(parser).end,
        subtreeStart, fieldCount + typeParameterCount * 65536);
    var structure = parser.nodes.data[root];
    structure.storage = methodCount as u64;
    parser.nodes.data[root] = structure;
    return root;
}

fn parseEnum(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parserPeek(parser).start;
    parser.current++;
    if (parserExpect(parser, TokenKind.Identifier) == false) return 0;
    val name = parserPrevious(parser);
    parserAdd(parser, AstKind.Name, name.start, name.end, parser.nodes.length, 0);
    var hasBacking: u64 = 0;
    if (parserMatch(parser, TokenKind.Colon)) {
        parseType(parser);
        hasBacking = parser.nodes.length - subtreeStart - 1;
    }
    if (parserExpect(parser, TokenKind.LeftBrace) == false) return 0;
    if (parserCheck(parser, TokenKind.RightBrace)) {
        parser.ok = false;
        return 0;
    }
    var count: u32 = 0;
    var parsing = true;
    while (parsing) {
        if (parserExpect(parser, TokenKind.Identifier) == false) return 0;
        val variant = parserPrevious(parser);
        val variantRoot = parserAdd(
            parser, AstKind.Name, variant.start, variant.end,
            parser.nodes.length, 0);
        if (parserMatch(parser, TokenKind.Equal)) {
            var negative: u32 = 0;
            if (parserMatch(parser, TokenKind.Plus)) {
            } else if (parserMatch(parser, TokenKind.Minus)) {
                negative = 1;
            }
            if (!parserExpect(parser, TokenKind.IntegerLiteral)) return 0;
            val value = parserPrevious(parser);
            var variantNode = parser.nodes.data[variantRoot];
            variantNode.conversionKind = 1;
            variantNode.storage = value.start;
            variantNode.typeName = value.end;
            variantNode.ownership = negative;
            parser.nodes.data[variantRoot] = variantNode;
        }
        count++;
        if (parserMatch(parser, TokenKind.Comma)) {
            if (parserCheck(parser, TokenKind.RightBrace)) {
                parser.ok = false;
                return 0;
            }
        } else {
            parsing = false;
        }
    }
    if (parserExpect(parser, TokenKind.RightBrace) == false) return 0;
    val root = parserAdd(
        parser, AstKind.EnumDeclaration, start, parserPrevious(parser).end,
        subtreeStart, count);
    var enumeration = parser.nodes.data[root];
    enumeration.storage = hasBacking;
    parser.nodes.data[root] = enumeration;
    return root;
}

fn parseModule(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parserPeek(parser).start;
    parser.current++;
    if (!parserExpect(parser, TokenKind.Identifier)) return 0;
    val firstName = parserPrevious(parser);
    parserAdd(
        parser, AstKind.Name, firstName.start, firstName.end,
        parser.nodes.length, 0);
    var partCount: u32 = 1;
    while (parserMatch(parser, TokenKind.Dot)) {
        if (!parserExpect(parser, TokenKind.Identifier)) return 0;
        val name = parserPrevious(parser);
        parserAdd(
            parser, AstKind.Name, name.start, name.end,
            parser.nodes.length, 0);
        partCount++;
    }
    if (!parserExpect(parser, TokenKind.Semicolon)) return 0;
    return parserAdd(
        parser, AstKind.ModuleDeclaration, start, parserPrevious(parser).end,
        subtreeStart, partCount);
}

fn parseImport(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parserPeek(parser).start;
    parser.current++;
    if (!parserExpect(parser, TokenKind.Identifier)) return 0;
    val firstName = parserPrevious(parser);
    parserAdd(
        parser, AstKind.Name, firstName.start, firstName.end,
        parser.nodes.length, 0);
    var partCount: u32 = 1;
    var isWildcard: u32 = 0;
    while (parserMatch(parser, TokenKind.Dot)) {
        if (parserMatch(parser, TokenKind.Star)) {
            isWildcard = 1;
            partCount++;
            break;
        }
        if (!parserExpect(parser, TokenKind.Identifier)) return 0;
        val name = parserPrevious(parser);
        parserAdd(
            parser, AstKind.Name, name.start, name.end,
            parser.nodes.length, 0);
        partCount++;
    }
    if (!parserExpect(parser, TokenKind.Semicolon)) return 0;
    return parserAdd(
        parser, AstKind.ImportDeclaration, start, parserPrevious(parser).end,
        subtreeStart, partCount + isWildcard * 65536);
}

fn parseConstant(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parserPeek(parser).start;
    parser.current++;
    if (!parserExpect(parser, TokenKind.Identifier)) return 0;
    val name = parserPrevious(parser);
    parserAdd(parser, AstKind.Name, name.start, name.end, parser.nodes.length, 0);
    var hasType: u32 = 0;
    if (parserMatch(parser, TokenKind.Colon)) { parseType(parser); hasType = 1; }
    if (!parserExpect(parser, TokenKind.Equal)) return 0;
    parseExpression(parser, 0);
    if (!parserExpect(parser, TokenKind.Semicolon)) return 0;
    return parserAdd(
        parser, AstKind.ConstantDeclaration, start,
        parserPrevious(parser).end, subtreeStart, hasType);
}
