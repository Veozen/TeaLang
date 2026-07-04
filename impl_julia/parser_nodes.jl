# 1. Define the Abstract Hierarchy Categories
abstract type ASTNode end
abstract type Statement <: ASTNode end
abstract type Expression <: ASTNode end

# 2. Base Structural Nodes
struct StmtBlock <: ASTNode
    line::Int
    column::Int
    statements::Vector{Statement}
end

struct Expr <: Expression
    line::Int
    column::Int
    tokens::Vector{ASTNode} # The RPN stream containing Identifiers, Integers, etc.
end

struct Identifier <: ASTNode
    line::Int
    column::Int
    name::String
end

struct IdentifierList <: ASTNode
    line::Int
    column::Int
    identifiers::Vector{Identifier}
end

# 3. Concrete Statements (All subtype '<:' Statement)
struct SetStmt <: Statement
    line::Int
    column::Int
    identifiers::IdentifierList
    expr::Expr
end

struct OutputStmt <: Statement
    line::Int
    column::Int
    expr::Expr
end

struct ErrorStmt <: Statement
    line::Int
    column::Int
    expr::Expr
end

struct ReturnStmt <: Statement
    line::Int
    column::Int
    expr::Expr
end

struct ExitStmt <: Statement
    line::Int
    column::Int
    condition::Expr
    expr::Expr
end

struct FuncStmt <: Statement
    line::Int
    column::Int
    name::String
    args::IdentifierList
    exit_stmt::Union{ExitStmt, Nothing} # Optional component
    body_stmt::StmtBlock
    return_stmt::ReturnStmt
end

struct ImportStmt <: Statement
    line::Int
    column::Int
    filename::Identifier
end

# 4. Primitive Types / Value Leaf Nodes
struct FunctionPointer <: ASTNode
    line::Int
    column::Int
    name::Identifier
end

struct IntegerNode <: ASTNode # Renamed to IntegerNode to avoid conflict with Julia's built-in Integer type
    line::Int
    column::Int
    value::Int64
end

struct Program <: ASTNode
    source_path::String
    body::StmtBlock
end
