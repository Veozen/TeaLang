//evaluator.d
module evaluator;

import std.stdio;
import std.file;
import std.string;
import std.array;
import std.exception;
import std.algorithm;
import std.conv : to;

import parser_nodes;
import lexer;
import parser;
import parser_nodes;

// ---------------- Environment ----------------

class Environment {
    // scopes: list of associative arrays (string -> int)
    int[string][] scopes;
    FuncStmt[string] functions;
    string[] functionIds;

    this() {
        int[string] root = null;
        scopes = [ root ];

        FuncStmt[string] functions;
        functions = null;   // empty AA

        functionIds = [
            "+", "-", "*", "/", "mod",
            "<", ">", "<=", ">=", "=",
            "peek", "extract", "exchange",
            "load", "store"
        ];
    }

    void pushScope(int[string] bindings) {
        scopes ~= bindings;
    }

    void popScope() {
        if (scopes.length > 1)
            scopes.length = scopes.length - 1;
    }

    int getVariableValue(string name) {
        auto frame = scopes[$ - 1];
        if (name in frame)
            return frame[name];
        throw new Exception("Runtime Error: Variable '" ~ name ~ "' is not defined in this scope.");
    }

    void defineFunction(string name, FuncStmt node) {
        if (!(name in functions))
            functionIds ~= name;
        functions[name] = node;
    }

    string getNameById(int funcId) {
        if (funcId >= 0 && funcId < functionIds.length)
            return functionIds[funcId];
        throw new Exception("Runtime Error: Invalid function ID " ~ funcId.to!string);
    }

    int getIdByName(string funcName) {
        int idx = functionIds.countUntil(funcName).to!int;
        if (idx < 0)
            throw new Exception("Runtime Error: function " ~ funcName ~ " is not defined");
        return idx;
    }
}

// ---------------- RPNEvaluator ----------------

class RPNEvaluator {
    Environment env;
    void delegate(FuncStmt, ref int[], ref int[]) executeFunctionCallback;
    void delegate(string, ref int[], ref int[]) executeOperatorCallback;

    this(Environment env) {
        this.env = env;
    }

    int[] evaluateExpr(Expr exprNode, ref int[] mainStack , ref int[] auxStack ) {

        foreach (token; exprNode.tokens) {
            // Integer
            if (auto i = cast(Integer) token) {
                mainStack ~= i.value;
                continue;
            }
            // FunctionPointer
            if (auto fp = cast(FunctionPointer) token) {
                auto funcName = fp.name.name;
                auto funcId   = env.getIdByName(funcName);
                mainStack ~= funcId;
                continue;
            }
            // Identifier vs Token
            string tok;
            if (auto id = cast(Identifier) token)
                tok = id.name;
            else {
                    throw new Exception("Runtime Error: Unexpected node type in expression");
                }



            // input
            if (tok == "input") {
                std.stdio.write("?", "");
                stdout.flush();
                auto line = readln().strip();
                try {
                    mainStack ~= line.to!int;
                } catch (Exception) {
                    throw new Exception("Runtime Error: 'input' expected an integer, but got '" ~ line ~ "'");
                }
            }
            // depth
            else if (tok == "depth") {
                auto frame = env.scopes[$ - 1];
                if ("depth" in frame)
                    mainStack ~= frame["depth"];
                else
                    mainStack ~= 0;
            }
            // apply
            else if (tok == "apply") {
                if (mainStack.length == 0)
                    throw new Exception("Runtime Error: Stack underflow during apply");
                auto funcId = mainStack[$ - 1];
                mainStack.length = mainStack.length - 1;

                auto funcName = env.getNameById(funcId);
                immutable builtins = [
                    "+", "-", "*", "/", "mod",
                    "<", ">", "<=", ">=", "=",
                    "peek", "extract", "exchange",
                    "load", "store"
                ];
                if (builtins.canFind(funcName)) {
                    executeOperatorCallback(funcName, mainStack, auxStack);
                } else {
                    auto funcObj = env.functions[funcName];
                    executeFunctionCallback(funcObj, mainStack, auxStack);
                }
            }
            // immediate function call
            else if (tok in env.functions) {
                auto funcObj = env.functions[tok];
                executeFunctionCallback(funcObj, mainStack, auxStack);
            }
            // variable
            else if (env.scopes.length > 0 &&
                     tok in env.scopes[$ - 1]) {
                mainStack ~= env.getVariableValue(tok);
            }
            // operator
            else {
                immutable ops = [
                    "+", "-", "*", "/", "mod",
                    "<", ">", "<=", ">=", "=",
                    "peek", "extract", "exchange",
                    "load", "store"
                ];
                if (ops.canFind(tok))
                    executeOperatorCallback(tok, mainStack, auxStack);
                else
                    throw new Exception("Runtime Error: Unknown operator or symbol '" ~ tok ~ "'");
            }
        }

        return mainStack.dup;
    }

    int[] evaluateExprWithNewStacks(Expr exprNode) {
        int[] mainStack = [];
        int[] auxStack = [];

        return evaluateExpr(exprNode,  mainStack,  auxStack);
    }
}

// ---------------- ASTInterpreter ----------------

class ASTInterpreter {
    Environment env;
    RPNEvaluator evaluator;

    this(Environment env) {
        this.env = env;
        this.evaluator = new RPNEvaluator(env);
        evaluator.executeFunctionCallback = &executeUserFunction;
        evaluator.executeOperatorCallback = &executeOperator;
    }

    void interpret(Program program) {
        foreach (stmt; program.body.statements) {
            executeStatements(stmt);
        }
    }

    void executeStatements(Node node) {
        //std.stdio.writeln("Visiting node: ", typeid(node));
        // SetStmt
        if (auto set = cast(SetStmt) node) {
            auto results = evaluator.evaluateExprWithNewStacks(set.expr);
            auto ids = set.identifiers.identifiers;
            foreach (i, varNode; ids) {
                auto varName = varNode.name;
                if (i < results.length)
                    env.scopes[$ - 1][varName] = results[i];
                else
                    throw new Exception("Runtime Error: Not enough values on the stack to assign to '" ~ varName ~ "'.");
            }
        }
        // FuncStmt
        else if (auto func = cast(FuncStmt) node) {
            auto fname = func.name; // in D version we stored string
            env.functions[fname] = func;
            env.functionIds ~= fname;
        }
        // StmtBlock
        else if (auto block = cast(StmtBlock) node) {
            foreach (stmt; block.statements)
                executeStatements(stmt);
        }
        // OutputStmt
        else if (auto outstmt = cast(OutputStmt) node) {
            auto results = evaluator.evaluateExprWithNewStacks(outstmt.expr);
            writeln(results.map!(to!string).join(" "));
        }
        // else {
        //     auto out = cast(OutputStmt) node;
        //     if (out !is null) {
        //         auto results = evaluator.evaluateExpr(out.expr);
        //         writeln(results.map!(to!string).join(" "));
        //         return;
        //     }
        // }

        // ErrorStmt
        else if (auto err = cast(ErrorStmt) node) {
            auto results = evaluator.evaluateExprWithNewStacks(err.expr);
            stderr.writeln("Error: " ~ results.map!(to!string).join(" "));
        }
        // ImportStmt
        else if (auto imp = cast(ImportStmt) node) {
            auto filename = imp.filename.name;
            string aliasName;

            if (imp.aliasName !is null) {
                aliasName = imp.aliasName.name;
                //std.stdio.writeln("\nimporting " ~ filename ~ " as " ~ aliasName);
            }
            else {
                aliasName = null; // or "" if you prefer
                //std.stdio.writeln("importing " ~ filename );
            }


            try {
                auto importedAst = parseFileToAst(filename);
                foreach (sub; importedAst.body.statements) {
                    if (auto f = cast(FuncStmt) sub) {
                        string funcName;
                        if (aliasName !is null)
                            funcName = aliasName ~ "." ~ f.name;
                        else
                            funcName = f.name;
                        env.functions[funcName] = f;
                        std.stdio.writeln("importing function " ~ funcName );
                    }
                }
            } catch (Exception e) {
                throw new Exception("Runtime Error: Could not find imported file '" ~ filename ~ "'");
            }
        }
    }

    void executeOperator(string op, ref int[] mainStack, ref int[] auxStack) {
        int a, b;
        if (op == "+" || op == "-" || op == "*" || op == "/" ||
            op == "mod" || op == "<" || op == ">" ||
            op == "<=" || op == ">=" || op == "=")
        {
            if (mainStack.length < 2)
                throw new Exception("Runtime Error: Stack underflow during " ~ op ~ " operation");
            b = mainStack[$ - 1];
            a = mainStack[$ - 2];
            mainStack.length = mainStack.length - 2;
        }
        if (op == "peek" || op == "extract" || op == "exchange" || op == "store") {
            if (mainStack.length < 1)
                throw new Exception("Runtime Error: Stack underflow during " ~ op ~ " operation");
        }
        if (op == "load") {
            if (auxStack.length < 1)
                throw new Exception("Runtime Error: Stack underflow during " ~ op ~ " operation");
        }

        switch (op) {
        case "+":
            mainStack ~= a + b;
            break;
        case "-":
            mainStack ~= a - b;
            break;
        case "*":
            mainStack ~= a * b;
            break;
        case "/":
            mainStack ~= a / b;
            break;
        case "mod":
            mainStack ~= a % b;
            break;
        case "<":
            mainStack ~= (a < b ? 1 : 0);
            break;
        case ">":
            mainStack ~= (a > b ? 1 : 0);
            break;
        case "<=":
            mainStack ~= (a <= b ? 1 : 0);
            break;
        case ">=":
            mainStack ~= (a >= b ? 1 : 0);
            break;
        case "=":
            mainStack ~= (a == b ? 1 : 0);
            break;
        case "peek": {
            auto index = mainStack[$ - 1];
            mainStack.length = mainStack.length - 1;
            auto target = cast(int)(mainStack.length - 1 - index);
            if (target < 0)
                throw new Exception("Runtime Error: Stack underflow during peek operation");
            auto value = mainStack[target];
            mainStack ~= value;
            break;
        }
        case "extract": {
            auto index = mainStack[$ - 1];
            mainStack.length = mainStack.length - 1;
            auto target = cast(int)(mainStack.length - 1 - index);
            if (target < 0)
                throw new Exception("Runtime Error: Stack underflow during pick operation");
            auto value = mainStack[target];
            mainStack = mainStack[0 .. target] ~ mainStack[target + 1 .. $];
            mainStack ~= value;
            break;
        }
        case "exchange": {
            auto index = mainStack[$ - 1];
            mainStack.length = mainStack.length - 1;
            auto target = cast(int)(mainStack.length - 1 - index);
            if (target < 0)
                throw new Exception("Runtime Error: Stack underflow during exchange");
            auto tmp = mainStack[target];
            mainStack[target] = mainStack[$ - 1];
            mainStack[$ - 1] = tmp;
            break;
        }
        case "load": {
            auto value = auxStack[$ - 1];
            auxStack.length = auxStack.length - 1;
            mainStack ~= value;
            break;
        }
        case "store": {
            auto value = mainStack[$ - 1];
            mainStack.length = mainStack.length - 1;
            auxStack ~= value;
            break;
        }
        default:
            throw new Exception("Unknown operator: " ~ op);
        }
    }

    void executeUserFunction(FuncStmt funcNode, ref int[] currentStack, ref int[] auxStack) {
        int callingDepth = currentStack.length.to!int;

        auto argsNodes = funcNode.args.identifiers;
        auto numArgs   = argsNodes.length;
        int[] args;
        foreach (_; 0 .. numArgs) {
            auto v = currentStack[$ - 1];
            currentStack.length = currentStack.length - 1;
            args ~= v;
        }
        args = args.reverse; // match Python’s [::-1]

        string[] paramNames;
        foreach (arg; argsNodes)
            paramNames ~= arg.name;

        int[string] localBindings;
        foreach (i, name; paramNames)
            localBindings[name] = args[i];

        localBindings["depth"] = callingDepth;

        env.pushScope(localBindings);

        try {
            if (funcNode.exitStmt !is null) {
                auto condResult = evaluator.evaluateExprWithNewStacks(funcNode.exitStmt.condition);
                if (condResult.length > 0 && condResult[$ - 1] != 0) {
                    evaluator.evaluateExpr(funcNode.exitStmt.expr, currentStack, auxStack);
                    return;
                }
            }

            executeStatements(funcNode.bodyStmt);
            evaluator.evaluateExpr(funcNode.returnStmt.expr, currentStack, auxStack);
        } finally {
            env.popScope();
        }
    }

    // FuncStmt isTailCall(Expr exprNode) {
    //     if (exprNode.tokens.length >= 1) {
    //         auto first = exprNode.tokens[0];
    //         string tokenStr;
    //         if (auto t = cast(Token) first)
    //             tokenStr = t.value;
    //         else if (auto id = cast(Identifier) first)
    //             tokenStr = id.name;
    //         else
    //             return null;
    //
    //         if (tokenStr in env.functions)
    //             return env.functions[tokenStr];
    //     }
    //     return null;
    // }
}

// ---------------- parse_file_to_ast ----------------

Program parseFileToAst(string filepath) {
    Token[] fileTokens;

    auto content = readText(filepath);
    auto lines = content.splitLines();
    foreach (lineNum, line; lines) {
        auto lineTokens = tokenize(line);
        foreach (ref t; lineTokens)
            t.line = cast(int)(lineNum + 1);
        fileTokens ~= lineTokens;
    }

    auto parser = new Parser(fileTokens);
    return parser.parseProgram();
}
