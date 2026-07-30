#include "lang/Ast.h"
#include "lang/Lexer.h"
#include "lang/Parser.h"
#include "lang/Source.h"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>

namespace {

class Dump {
public:
    explicit Dump(const k::Source& source) : source_{source} {}

    void node(unsigned kind, k::SourceSpan span, std::size_t subtree,
              unsigned aux = 0) {
        std::cout << kind << ':' << span.start << ':' << span.end << ':'
                  << subtree << ':' << aux << ';';
    }

    void type(const k::Type& value) {
        const auto subtree = index_;
        std::visit([&](const auto& item) { typeNode(item, value, subtree); },
                   value.node);
    }

    void expression(const k::Expr& value) {
        const auto subtree = index_;
        std::visit([&](const auto& item) { exprNode(item, value, subtree); },
                   value.node);
    }

    void statement(const k::Stmt& value) {
        const auto subtree = index_;
        std::visit([&](const auto& item) { stmtNode(item, value, subtree); },
                   value.node);
    }

    void program(const k::Program& value) {
        for (const auto& enumeration : value.enums) {
            const auto subtree = index_;
            add(45, enumeration.name, index_);
            for (const auto& variant : enumeration.variants)
                add(45, variant.name, index_);
            add(47, enumeration.span, subtree,
                static_cast<unsigned>(enumeration.variants.size()));
        }
        for (const auto& structure : value.structs) {
            const auto subtree = index_;
            add(45, structure.name, index_);
            for (const auto& field : structure.fields) {
                const auto fieldSubtree = index_;
                add(45, field.name, index_);
                type(*field.type);
                add(42, field.span, fieldSubtree);
            }
            for (const auto& method : structure.methods) dumpFunction(method);
            add(43, structure.span, subtree,
                static_cast<unsigned>(structure.fields.size()));
        }
        for (const auto& function : value.functions) dumpFunction(function);
        add(44, value.span, 0,
            static_cast<unsigned>(value.enums.size() + value.structs.size() +
                                  value.functions.size()));
    }

private:
    void dumpFunction(const k::FunctionDecl& function) {
            const auto subtree = index_;
            add(45, function.name, index_);
            for (const auto& parameter : function.typeParameters) {
                const auto parameterSubtree = index_;
                add(45, parameter.name, index_);
                if (parameter.constraint)
                    add(45, *parameter.constraint, index_);
                add(
                    46, parameter.span, parameterSubtree,
                    parameter.constraint ? 1u : 0u);
            }
            for (const auto& parameter : function.parameters) {
                const auto parameterSubtree = index_;
                add(45, parameter.name, index_);
                type(*parameter.type);
                add(40, parameter.span, parameterSubtree,
                    static_cast<unsigned>(parameter.mode));
            }
            type(*function.returnType);
            if (function.body) block(*function.body);
            auto aux = static_cast<unsigned>(function.parameters.size());
            if (function.isExtern) aux += 65536;
            aux += static_cast<unsigned>(
                function.typeParameters.size() * 131072);
            add(41, function.span, subtree, aux);
    }
    void add(unsigned kind, k::SourceSpan span, std::size_t subtree,
             unsigned aux = 0) {
        node(kind, span, subtree, aux);
        ++index_;
    }

    unsigned tokenKind(k::SourceSpan span) const {
        for (const auto& token : k::Lexer{source_}.lexAll().tokens)
            if (token.span.start == span.start)
                return static_cast<unsigned>(token.kind);
        return 0;
    }

    void typeNode(const k::NamedType&, const k::Type& value,
                  std::size_t subtree) {
        add(1, value.span, subtree, tokenKind(value.span));
    }
    void typeNode(const k::PointerType& item, const k::Type& value,
                  std::size_t subtree) {
        type(*item.pointee);
        add(2, value.span, subtree);
    }
    void typeNode(const k::NullableType& item, const k::Type& value,
                  std::size_t subtree) {
        type(*item.inner);
        add(3, value.span, subtree);
    }
    void typeNode(const k::SliceType& item, const k::Type& value,
                  std::size_t subtree) {
        type(*item.element);
        add(4, value.span, subtree);
    }
    void typeNode(const k::ArrayType& item, const k::Type& value,
                  std::size_t subtree) {
        type(*item.element);
        if (item.size) expression(*item.size);
        add(5, value.span, subtree, item.size ? 1 : 0);
    }
    template <typename T>
    void typeNode(const T&, const k::Type& value, std::size_t subtree) {
        add(1, value.span, subtree, tokenKind(value.span));
    }

    void exprNode(const k::IdentifierExpr&, const k::Expr& value,
                  std::size_t subtree) {
        add(10, value.span, subtree);
    }
    void exprNode(const k::LiteralExpr& item, const k::Expr& value,
                  std::size_t subtree) {
        add(11, value.span, subtree, static_cast<unsigned>(item.kind));
    }
    void exprNode(const k::UnaryExpr& item, const k::Expr& value,
                  std::size_t subtree) {
        expression(*item.operand);
        add(12, value.span, subtree, static_cast<unsigned>(item.op));
    }
    void exprNode(const k::BinaryExpr& item, const k::Expr& value,
                  std::size_t subtree) {
        expression(*item.left);
        expression(*item.right);
        add(13, value.span, subtree, static_cast<unsigned>(item.op));
    }
    void exprNode(const k::AssignmentExpr& item, const k::Expr& value,
                  std::size_t subtree) {
        expression(*item.target);
        expression(*item.value);
        add(14, value.span, subtree, static_cast<unsigned>(item.op));
    }
    void exprNode(const k::CastExpr& item, const k::Expr& value,
                  std::size_t subtree) {
        expression(*item.value);
        type(*item.type);
        add(15, value.span, subtree);
    }
    void exprNode(const k::CallExpr& item, const k::Expr& value,
                  std::size_t subtree) {
        expression(*item.callee);
        for (const auto& argument : item.typeArguments) type(*argument);
        for (const auto& argument : item.arguments) expression(*argument);
        add(16, value.span, subtree,
            static_cast<unsigned>(
                item.arguments.size() +
                item.typeArguments.size() * 65536));
    }
    void exprNode(const k::MemberExpr& item, const k::Expr&,
                  std::size_t subtree) {
        expression(*item.object);
        add(17, item.name, subtree);
    }
    void exprNode(const k::IndexExpr& item, const k::Expr& value,
                  std::size_t subtree) {
        expression(*item.object);
        expression(*item.index);
        add(18, value.span, subtree);
    }
    void exprNode(const k::PostfixExpr& item, const k::Expr& value,
                  std::size_t subtree) {
        expression(*item.value);
        add(19, value.span, subtree, static_cast<unsigned>(item.op));
    }
    void exprNode(const k::UnitLiteralExpr&, const k::Expr& value,
                  std::size_t subtree) {
        add(20, value.span, subtree);
    }
    void exprNode(const k::SizeofExpr& item, const k::Expr& value,
                  std::size_t subtree) {
        type(*item.type);
        add(21, value.span, subtree);
    }
    void exprNode(const k::ArrayLiteralExpr& item, const k::Expr& value,
                  std::size_t subtree) {
        for (const auto& element : item.elements) expression(*element);
        add(22, value.span, subtree,
            static_cast<unsigned>(item.elements.size()));
    }
    void exprNode(const k::WhenExpr& item, const k::Expr& value,
                  std::size_t subtree) {
        if (item.subject) expression(*item.subject);
        for (const auto& branch : item.branches) {
            const auto branchSubtree = index_;
            for (const auto& condition : branch.conditions) expression(*condition);
            for (const auto& statement : branch.body->statements)
                this->statement(*statement);
            expression(*branch.value);
            add(24, value.span, branchSubtree,
                static_cast<unsigned>((branch.conditions.empty() ? 1 : 0) +
                                      branch.body->statements.size() * 2 +
                                      branch.conditions.size() * 65536));
        }
        add(23, value.span, subtree,
            static_cast<unsigned>(item.branches.size() +
                                  (item.subject ? 65536 : 0)));
    }
    void exprNode(const k::IfExpr& item, const k::Expr& value,
                  std::size_t subtree) {
        expression(*item.condition);
        for (const auto& statement : item.thenBranch.body->statements)
            this->statement(*statement);
        expression(*item.thenBranch.value);
        for (const auto& statement : item.elseBranch.body->statements)
            this->statement(*statement);
        expression(*item.elseBranch.value);
        add(25, value.span, subtree,
            static_cast<unsigned>(item.thenBranch.body->statements.size() +
                item.elseBranch.body->statements.size() * 65536));
    }
    template <typename T>
    void exprNode(const T&, const k::Expr& value, std::size_t subtree) {
        add(0, value.span, subtree);
    }

    void block(const k::BlockStmt& item) {
        const auto subtree = index_;
        for (const auto& statement : item.statements) this->statement(*statement);
        add(30, {0, 0}, subtree, static_cast<unsigned>(item.statements.size()));
    }

    void stmtNode(const k::BlockStmt& item, const k::Stmt& value,
                  std::size_t) {
        block(item);
    }
    void stmtNode(const k::IfStmt& item, const k::Stmt& value,
                  std::size_t subtree) {
        expression(*item.condition);
        block(*item.thenBranch);
        if (item.elseBranch) block(*item.elseBranch);
        add(31, value.span, subtree, item.elseBranch ? 1 : 0);
    }
    void stmtNode(const k::WhileStmt& item, const k::Stmt& value,
                  std::size_t subtree) {
        expression(*item.condition);
        block(*item.body);
        add(32, value.span, subtree);
    }
    void stmtNode(const k::ForStmt& item, const k::Stmt& value,
                  std::size_t subtree) {
        add(45, item.valueName, index_);
        if (item.indexName) add(45, *item.indexName, index_);
        expression(*item.collection);
        block(*item.body);
        add(38, value.span, subtree, item.indexName ? 1 : 0);
    }
    void stmtNode(const k::WhenStmt& item, const k::Stmt& value,
                  std::size_t subtree) {
        if (item.subject) expression(*item.subject);
        for (const auto& branch : item.branches) {
            const auto branchSubtree = index_;
            for (const auto& condition : branch.conditions) expression(*condition);
            block(*branch.body);
            add(40, value.span, branchSubtree,
                static_cast<unsigned>((branch.conditions.empty() ? 1 : 0) +
                                      branch.conditions.size() * 65536));
        }
        add(39, value.span, subtree,
            static_cast<unsigned>(item.branches.size()) +
                (item.subject ? 65536u : 0u));
    }
    void stmtNode(const k::BreakStmt&, const k::Stmt& value,
                  std::size_t subtree) {
        add(36, value.span, subtree);
    }
    void stmtNode(const k::ContinueStmt&, const k::Stmt& value,
                  std::size_t subtree) {
        add(37, value.span, subtree);
    }
    void stmtNode(const k::VariableDecl& item, const k::Stmt& value,
                  std::size_t subtree) {
        add(45, item.name, index_);
        if (item.declaredType) type(*item.declaredType);
        expression(*item.initializer);
        add(33, value.span, subtree,
            item.mode == k::VariableMode::Val ? 6 : 7);
    }
    void stmtNode(const k::ReturnStmt& item, const k::Stmt& value,
                  std::size_t subtree) {
        if (item.value) expression(*item.value);
        add(34, value.span, subtree, item.value ? 1 : 0);
    }
    void stmtNode(const k::DeferStmt& item, const k::Stmt& value,
                  std::size_t subtree) {
        statement(*item.statement);
        add(41, value.span, subtree);
    }
    void stmtNode(const k::ExpressionStmt& item, const k::Stmt& value,
                  std::size_t subtree) {
        expression(*item.expression);
        add(35, value.span, subtree);
    }

    const k::Source& source_;
    std::size_t index_ = 0;
};

}

int main(int argc, char** argv) {
    if (argc != 2) return 1;
    std::ifstream input{std::filesystem::path{argv[1]}, std::ios::binary};
    if (!input) return 1;
    std::string text{std::istreambuf_iterator<char>{input},
                     std::istreambuf_iterator<char>{}};
    k::Source source{argv[1], std::move(text)};
    const auto lexed = k::Lexer{source}.lexAll();
    if (lexed.error) return 2;
    auto parsed = k::Parser{source, lexed.tokens}.parseProgram();
    if (!parsed.diagnostics.empty()) return 2;
    Dump{source}.program(parsed.program);
    return 0;
}
