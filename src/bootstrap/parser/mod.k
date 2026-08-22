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
    if (parser.check(TokenKind.KwModule)) {
        parseModule(parser);
        declarationCount++;
    }
    while (parser.check(TokenKind.KwImport)) {
        parseImport(parser);
        declarationCount++;
    }
    while (parser.ok) {
        if (parser.check(TokenKind.EndOfFile)) break;
        if (parser.check(TokenKind.KwModule)) {
            parseModule(parser);
        } else if (parser.check(TokenKind.KwImport)) {
            parseImport(parser);
        } else if (parser.check(TokenKind.KwEnum)) {
            parseEnum(parser);
        } else if (parser.check(TokenKind.KwConst)) {
            parseConstant(parser);
        } else if (parser.check(TokenKind.KwStruct)) {
            parseStruct(parser);
        } else {
            var isExtern = false;
            val declarationStart = parser.peek().start;
            if (parser.match(TokenKind.KwExtern)) isExtern = true;
            parseFunction(parser, isExtern, declarationStart, 0, 0);
        }
        declarationCount++;
    }
    var ok = false;
    var errorStart: u64 = 0;
    var expectedKind: u32 = 0;
    if (parser.check(TokenKind.EndOfFile)) {
        val end = parser.peek().end;
        parser.add(AstKind.Program, start, end, 0, declarationCount);
        ok = true;
    } else {
        errorStart = parser.peek().start;
        expectedKind = parser.expectedKind;
    }
    return ParseResult(parser.nodes, ok, errorStart, expectedKind);
}
