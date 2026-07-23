//parser_nodes.d
module parser_nodes;

// Base AST node
class Node {
    int line;
    int column;

    this(int line, int column) {
        this.line = line;
        this.column = column;
    }
}

// ---------------- Statements ----------------

class Statement : Node {
    this(int line, int column) {
        super(line, column);
    }
}

class StmtBlock : Node {
    Statement[] statements;

    this(int line, int column, Statement[] statements) {
        super(line, column);
        this.statements = statements;
    }
}

// ---------------- Expressions ----------------

class Expr : Node {
    Node[] tokens; // RPN stream

    this(int line, int column, Node[] tokens) {
        super(line, column);
        this.tokens = tokens;
    }
}

// ---------------- Identifiers ----------------

class Identifier : Node {
    string name;

    this(int line, int column, string name) {
        super(line, column);
        this.name = name;
    }
}

class IdentifierList : Node {
    Identifier[] identifiers;

    this(int line, int column, Identifier[] identifiers) {
        super(line, column);
        this.identifiers = identifiers;
    }
}

// ---------------- Statement Types ----------------

class SetStmt : Statement {
    IdentifierList identifiers;
    Expr expr;

    this(int line, int column, IdentifierList identifiers, Expr expr) {
        super(line, column);
        this.identifiers = identifiers;
        this.expr = expr;
    }
}

class OutputStmt : Statement {
    Expr expr;

    this(int line, int column, Expr expr) {
        super(line, column);
        this.expr = expr;
    }
}

class ErrorStmt : Statement {
    Expr expr;

    this(int line, int column, Expr expr) {
        super(line, column);
        this.expr = expr;
    }
}

class ReturnStmt : Statement {
    Expr expr;

    this(int line, int column, Expr expr) {
        super(line, column);
        this.expr = expr;
    }
}

class ExitStmt : Statement {
    Expr condition;
    Expr expr;

    this(int line, int column, Expr condition, Expr expr) {
        super(line, column);
        this.condition = condition;
        this.expr = expr;
    }
}

class FuncStmt : Statement {
    string name;
    IdentifierList args;
    ExitStmt exitStmt;
    StmtBlock bodyStmt;
    ReturnStmt returnStmt;

    this(int line, int column,
         string name,
         IdentifierList args,
         ExitStmt exitStmt,
         StmtBlock bodyStmt,
         ReturnStmt returnStmt)
    {
        super(line, column);
        this.name = name;
        this.args = args;
        this.exitStmt = exitStmt;
        this.bodyStmt = bodyStmt;
        this.returnStmt = returnStmt;
    }
}

class ImportStmt : Statement {
    Identifier filename;
    Identifier aliasName;

    this(int line, int column, Identifier filename, Identifier aliasName) {
        super(line, column);
        this.filename = filename;
        this.aliasName = aliasName;
    }
}

// ---------------- Other Node Types ----------------

class FunctionPointer : Node {
    Identifier name;

    this(int line, int column, Identifier name) {
        super(line, column);
        this.name = name;
    }
}

class Integer : Node {
    int value;

    this(int line, int column, int value) {
        super(line, column);
        this.value = value;
    }
}

class Program : Node {
    string sourcePath;
    StmtBlock body;

    this(int line, int column, string sourcePath, StmtBlock body) {
        super(line, column);
        this.sourcePath = sourcePath;
        this.body = body;
    }
}

// Optional future nodes:
//
// class IfStmt : Statement { ... }
// class WhileStmt : Statement { ... }
