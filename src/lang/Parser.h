#pragma once

#include "lang/Ast.h"
#include "lang/Diagnostic.h"
#include "lang/Token.h"

#include <optional>
#include <vector>

namespace k {

struct ParseResult {
    Program program;
    std::vector<Diagnostic> diagnostics;
};

class Parser {
public:
    Parser(const Source& source, const std::vector<Token>& tokens);
    [[nodiscard]] ParseResult parseProgram();

private:
    [[nodiscard]] const Token& peek() const noexcept;
    [[nodiscard]] const Token& previous() const noexcept;
    [[nodiscard]] bool atEnd() const noexcept;
    [[nodiscard]] bool check(TokenKind kind) const noexcept;
    bool match(TokenKind kind);
    const Token& advance();
    bool expect(TokenKind kind, std::string message);
    void report(SourceSpan span, std::string message);

    [[nodiscard]] std::optional<ModuleDecl> parseModule();
    [[nodiscard]] std::optional<ImportDecl> parseImport();
    [[nodiscard]] std::optional<FunctionDecl> parseFunction(bool isExtern);
    [[nodiscard]] std::optional<StructDecl> parseStruct();
    [[nodiscard]] std::optional<Parameter> parseParameter();
    [[nodiscard]] std::unique_ptr<BlockStmt> parseBlock(SourceSpan& span);
    [[nodiscard]] StmtPtr parseStatement();
    [[nodiscard]] StmtPtr parseIf();
    [[nodiscard]] StmtPtr parseWhile();
    [[nodiscard]] StmtPtr parseFor();
    [[nodiscard]] StmtPtr parseWhen();
    [[nodiscard]] std::unique_ptr<BlockStmt> parseControlBody(SourceSpan& span);
    [[nodiscard]] StmtPtr parseVariable();
    [[nodiscard]] StmtPtr parseReturn();
    [[nodiscard]] StmtPtr parseExpressionStatement();

    [[nodiscard]] TypePtr parseType();
    [[nodiscard]] TypePtr parseUnionType();
    [[nodiscard]] TypePtr parsePostfixType();
    [[nodiscard]] TypePtr parsePrimaryType();

    [[nodiscard]] ExprPtr parseExpression(int minimumBindingPower = 0);
    [[nodiscard]] ExprPtr parsePrefix();
    [[nodiscard]] ExprPtr parsePrimary();
    [[nodiscard]] ExprPtr parseCall(
        ExprPtr callee, std::vector<TypePtr> typeArguments = {});
    [[nodiscard]] bool genericCallAhead() const noexcept;

    void synchronizeStatement();
    void synchronizeTopLevel();

    const Source& source_;
    const std::vector<Token>& tokens_;
    std::size_t current_ = 0;
    std::vector<Diagnostic> diagnostics_;
};

}
