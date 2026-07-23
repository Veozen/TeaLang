import std.stdio;
import std.string;
import std.array;
import std.exception;
import std.algorithm;
import std.conv : to;

import parser_nodes;
import lexer;

// ---------------------------------------------
// TeaLang Parser (D version of your Python code)
// ---------------------------------------------

class Parser {
    Token[] tokens;
    size_t pos;

    string[] reservedKeywords = [
        "set", "func", "return", "output", "error", "exit", "import",
        "when", "as", ";",
        "input", "depth", "+", "-", "*", "/", "mod", "min", "max",
        "<", ">", "<=", ">=", "=", "fn", "apply", "peek", "extract", "exchange"
    ];

    string[] expressionTerminator = [
        "set", "func", "return", "output", "error", "when", "as", ";"
    ];

    string[] identifierListTerminator = ["as"];

    bool isInsideFunction = false;

    this(Token[] tokens) {
        this.tokens = tokens;
        this.pos = 0;
    }

    // ---------------- Utility ----------------

    // Nullable!Token peek(int distance = 0) {
    //     size_t idx = pos + distance;
    //     if (idx < tokens.length)
    //         return Nullable!Token(tokens[idx]);
    //     return Nullable!Token.init; // null state
    // }

    Token* peek(size_t distance = 0) {
        size_t idx = pos + distance;
        return idx < tokens.length ? &tokens[idx] : null;
    }

    Token* advance() {
        auto t = peek();
        if (t !is null) pos++;
        return t;
    }

    void expect(string value) {
        auto t = peek();
        if (t is null || t.value != value)
            throw new Exception("Expected "~value~", got "~(t ? t.toString : "EOF"));
        advance();
    }

    Token* consume(string expectedValue = null) {
        auto t = peek();
        if (t is null)
            throw new Exception("Unexpected end of input");

        if (expectedValue !is null && t.value != expectedValue)
            throw new Exception("Expected "~expectedValue~" at L:"~
                                t.line.to!string~" C:"~t.col.to!string~
                                ", got "~t.value);

        pos++;
        return t;
    }


    // ---------------- Program ----------------

    Program parseProgram() {
        auto first = peek();
        int line = first ? first.line : 1;
        int col  = first ? first.col  : 1;

        Statement[] statements;

        // Parse imports first
        while (peek() !is null && peek().value == "import")
            statements ~= parseImport();

        // Parse rest of program
        while (peek() !is null)
            statements ~= parseStatement();

        auto body = new StmtBlock(line, col, statements);
        return new Program(line, col, "", body);
    }

    // ---------------- Statements ----------------

    Statement parseStatement() {
        auto t = peek();
        if (t is null)
            throw new Exception("Unexpected EOF in statement");

        switch (t.value) {
            case "set":    return parseSet();
            case "func":   return parseFunc();
            case "output": return parseOutput();
            case "error":  return parseError();
            default:
                throw new Exception("Unexpected statement: "~t.value);
        }
    }

    // set x as expr
    SetStmt parseSet() {
        auto start = peek();
        consume("set");

        auto idList = parseIdentifierList();
        auto expr   = parseExpr();

        if (expr.tokens.length == 0)
            throw new Exception("Parser Error: 'set' requires non-empty expression");

        return new SetStmt(start.line, start.col, idList, expr);
    }

    // func name args [exit guard] body return
    FuncStmt parseFunc() {
        auto start = peek();

        if (isInsideFunction)
            throw new Exception("Nested functions are banned");

        isInsideFunction = true;

        Token* nameTok;        // <-- FIX: declare here
        ExitStmt guardStmt;
        ReturnStmt returnStmt;
        IdentifierList args;
        StmtBlock bodyBlock;

        try {
            consume("func");
            nameTok = advance();
            args    = parseIdentifierList();

            if (nameTok.value.canFind('.'))
                throw new Exception("Invalid function name: contains '.'");

            // Optional guard
            if (peek().value == "exit")
                guardStmt = parseExit();

            // Body block
            Statement[] statements;
            auto first = peek();
            int line = first ? first.line : 1;
            int col  = first ? first.col  : 1;

            while (peek() !is null && peek().value != "return")
                statements ~= parseStatement();

            bodyBlock = new StmtBlock(line, col, statements);

            if (peek().value != "return")
                throw new Exception("Malformed function: missing final return");

            returnStmt = parseReturn();
        }
        finally {
            isInsideFunction = false;
        }

        return new FuncStmt(
            start.line, start.col,
            nameTok.value,
            args,
            guardStmt,
            bodyBlock,
            returnStmt
        );
    }

    OutputStmt parseOutput() {
        auto start = peek();
        consume("output");
        auto expr = parseExpr();
        return new OutputStmt(start.line, start.col, expr);
    }

    ErrorStmt parseError() {
        auto start = peek();
        consume("error");
        auto expr = parseExpr();
        return new ErrorStmt(start.line, start.col, expr);
    }

    ImportStmt parseImport() {
        auto start = peek();
        consume("import");

        auto filename = parseIdentifier();
        Identifier aliasName  = null;

        if (peek() !is null && peek().value == "as") {
            consume("as");
            aliasName = parseIdentifier();
        }
        return new ImportStmt(start.line, start.col, filename, aliasName);
    }

    ReturnStmt parseReturn() {
        auto start = peek();
        consume("return");
        auto expr = parseExpr();
        return new ReturnStmt(start.line, start.col, expr);
    }

    ExitStmt parseExit() {
        auto start = peek();
        consume("exit");

        auto expr = parseExpr();
        auto cur = peek();

        if (cur.value != "when")
            throw new Exception("Expected 'when', got "~cur.value);

        consume("when");
        auto cond = parseExpr();

        if (cond.tokens.length == 0)
            throw new Exception("'when' must be followed by non-empty expression");

        return new ExitStmt(start.line, start.col, cond, expr);
    }

    // ---------------- Identifiers ----------------

    IdentifierList parseIdentifierList() {
        auto start = peek();
        Identifier[] ids;

        while (peek() !is null &&
               !identifierListTerminator.canFind(peek().value))
        {
            ids ~= parseIdentifier();
        }

        consume("as");

        return new IdentifierList(start.line, start.col, ids);
    }

    Identifier parseIdentifier() {
        auto cur = peek();

        if (cur is null)
            throw new Exception("Unexpected EOF in statement");

        auto tok = advance();
        auto name = tok.value;

        if (name.isNumeric)
            throw new Exception("Invalid identifier: numeric constant");

        if (reservedKeywords.canFind(name))
            throw new Exception("Invalid identifier: reserved keyword");

        return new Identifier(cur.line, cur.col, name);
    }

    // ---------------- Expressions ----------------

    Expr parseExpr() {
        auto start = peek();
        Node[] nodes;

        while (true) {
            auto tok = peek();
            if (tok is null) break;
            if (expressionTerminator.canFind(tok.value)) break;

            if (tok.value == "fn") {
                consume("fn");
                auto nameTok = advance();
                // Construct an Identifier node from the token
                auto id = new Identifier(nameTok.line, nameTok.col, nameTok.value);
                nodes ~= new FunctionPointer(nameTok.line, nameTok.col, id);
            }
            else if (tok.value.isNumeric) {
                auto numTok = advance();
                nodes ~= new Integer(numTok.line, numTok.col, numTok.value.to!int);
            }
            else {
                tok = advance();
                nodes ~= new Identifier(tok.line, tok.col, tok.value);
            }
        }

        int line = start ? start.line : 1;
        int col  = start ? start.col  : 1;

        return new Expr(line, col, nodes);
    }
}
