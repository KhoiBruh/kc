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
    val start = parserPeek(parser).start;
    var declarationCount: u32 = 0;
    if (parserCheck(parser, TokenKind.KwModule)) {
        parseModule(parser);
        declarationCount++;
    }
    while (parserCheck(parser, TokenKind.KwImport)) {
        parseImport(parser);
        declarationCount++;
    }
    while (parser.ok) {
        if (parserCheck(parser, TokenKind.EndOfFile)) break;
        if (parserCheck(parser, TokenKind.KwModule)) {
            parseModule(parser);
        } else if (parserCheck(parser, TokenKind.KwImport)) {
            parseImport(parser);
        } else if (parserCheck(parser, TokenKind.KwEnum)) {
            parseEnum(parser);
        } else if (parserCheck(parser, TokenKind.KwConst)) {
            parseConstant(parser);
        } else if (parserCheck(parser, TokenKind.KwStruct)) {
            parseStruct(parser);
        } else {
            var isExtern = false;
            val declarationStart = parserPeek(parser).start;
            if (parserMatch(parser, TokenKind.KwExtern)) isExtern = true;
            parseFunction(parser, isExtern, declarationStart, 0, 0);
        }
        declarationCount++;
    }
    var ok = false;
    var errorStart: u64 = 0;
    var expectedKind: u32 = 0;
    if (parserCheck(parser, TokenKind.EndOfFile)) {
        val end = parserPeek(parser).end;
        parserAdd(parser, AstKind.Program, start, end, 0, declarationCount);
        ok = true;
    } else {
        errorStart = parserPeek(parser).start;
        expectedKind = parser.expectedKind;
    }
    return ParseResult(parser.nodes, ok, errorStart, expectedKind);
}
