module bootstrap.parser;

import bootstrap.token.Token;
import bootstrap.token.TokenKind;
import bootstrap.list.List;
import bootstrap.ast.AstKind;
import bootstrap.ast.AstNode;
import bootstrap.ast.ParameterMode;
import bootstrap.parser.core.Parser;
import bootstrap.parser.types.isTypeStart;
import bootstrap.parser.expressions.parseExpression;
import bootstrap.parser.statements.parseStatement;
import bootstrap.parser.declarations.parseFunction;

fn parse(val tokens: List<Token>): ParseResult {
    var parser = Parser(tokens, List<AstNode>.new(), 0, true, 0);
    val start = parser.peek().start;
    var declarationCount: u32 = 0;
    if (parser.check(TokenKind.MODULE)) {
        parseModule(parser);
        declarationCount++;
    }
    while (parser.check(TokenKind.IMPORT)) {
        parseImport(parser);
        declarationCount++;
    }
    while (parser.ok) {
        if (parser.check(TokenKind.EOF)) break;
        if (parser.check(TokenKind.MODULE)) {
            parseModule(parser);
        } else if (parser.check(TokenKind.IMPORT)) {
            parseImport(parser);
        } else if (parser.check(TokenKind.ENUM)) {
            parseEnum(parser);
        } else if (parser.check(TokenKind.CONST)) {
            parseConstant(parser);
        } else if (parser.check(TokenKind.STRUCT)) {
            parseStruct(parser);
        } else {
            var isExtern = false;
            val declarationStart = parser.peek().start;
            if (parser.match(TokenKind.EXTERN)) isExtern = true;
            parseFunction(parser, isExtern, declarationStart, 0, 0);
        }
        declarationCount++;
    }
    var ok = false;
    var errorStart: u64 = 0;
    var expectedKind: u32 = 0;
    if (parser.check(TokenKind.EOF)) {
        val end = parser.peek().end;
        parser.add(AstKind.PROGRAM, start, end, 0, declarationCount);
        ok = true;
    } else {
        errorStart = parser.peek().start;
        expectedKind = parser.expectedKind;
    }
    return ParseResult(parser.nodes, ok, errorStart, expectedKind);
}
