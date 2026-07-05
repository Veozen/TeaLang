include("parser_nodes.jl")


# 1. Define the Mutable State
mutable struct Parser
    tokens::Vector{Token}
    pos::Int  # Starts at 1 for Julia
    reserved_keywords::Set{String}
    expression_terminator::Set{String}
    identifier_list_terminator::Set{String}
    is_inside_function::Bool

    # Custom constructor to match Python's __init__
    function Parser(tokens::Vector{Token})
        new(
            tokens,
            1, # 1-based indexing
            Set(["set", "func", "return", "output", "error", "exit", "import", "when", "as", ";", "input", "depth", "+", "-", "*", "/", "mod", "min", "max", "<", ">", "<=", ">=", "=", "fn", "apply", "peek", "extract", "exchange"]),
            Set(["set", "func", "return", "output", "error", "when", "as", ";"]),
            Set(["as"]),
            false
        )
    end
end

# --- CORE PARSER METHODS (Functions Outside the Struct) ---

function peek_token(p::Parser, distance::Int=0)
    idx = p.pos + distance
    if idx <= length(p.tokens)
        return p.tokens[idx]
    else
        return nothing
    end
end

# Mutates parser position, so we suffix with !
function advance!(p::Parser)
    token = peek_token(p)
    if !isnothing(token)
        p.pos += 1
    end
    return token
end

function expect!(p::Parser, token_value::String)
    token = peek_token(p)
    if isnothing(token) || token.value != token_value
        error("SyntaxError: Expected $token_value, got $(isnothing(token) ? "EOF" : token)")
    end
    advance!(p)
    return true
end

function consume!(p::Parser, expected_value::Union{String, Nothing}=nothing)
    token = peek_token(p)
    if isnothing(token)
        error("Exception: Unexpected end of input")
    end

    if !isnothing(expected_value) && token.value != expected_value
        error("Exception: Expected $expected_value at L:$(token.line) C:$(token.col), got $(token.value)")
    end
    p.pos += 1
    return token
end

# --- GRAMMAR PARSING METHODS ---

function parse_program!(p::Parser)
    statements = Statement[] # Or use a shared abstract type like Statement[]

    first_token = peek_token(p)
    line = !isnothing(first_token) ? first_token.line : 1
    col = !isnothing(first_token) ? first_token.col : 1

    # parse imports first
    while !isnothing(peek_token(p)) && peek_token(p).value == "import"
        push!(statements, parse_import!(p))
    end

    # parse rest of program
    while !isnothing(peek_token(p))
        push!(statements, parse_statement!(p))
    end

    main_body = StmtBlock(line, col, statements)
    return Program("", main_body)
end

function parse_statement!(p::Parser)
    token = peek_token(p)
    if isnothing(token)
        error("SyntaxError: Expected statement, got EOF")
    end
    println(stderr,token)
    if token.value == "set"
        return parse_set!(p)
    elseif token.value == "func"
        return parse_func!(p)
    elseif token.value == "output"
        return parse_output!(p)
    elseif token.value == "error"
        return parse_error!(p)
    end

    error("SyntaxError: Unexpected statement: $(token.value) L:$(token.line) C:$(token.col)")
end


# --- STATEMENT PARSERS ---

function parse_set!(p::Parser)
    start_token = peek_token(p)
    consume!(p, "set")

    identifier_list = parse_identifier_list!(p)
    expr = parse_expr!(p)

    # Force an error for 'set x as ;'
    if isempty(expr.tokens)
        names = join([id.name for id in identifier_list.identifiers], " ")
        error("SyntaxError: Parser Error: 'set $names as' requires a non-empty expression")
    end

    return SetStmt(
        start_token.line,
        start_token.col,
        identifier_list,
        expr
    )
end

function parse_func!(p::Parser)
    start_token = peek_token(p)

    # 1. No Nested function definitions allowed
    if p.is_inside_function
        error("SyntaxError: Nested functions are banned. Cannot declare a function inside another function at line $(start_token.line).")
    end

    p.is_inside_function = true

    # Declare variables outside the try block so they are accessible after it
    local name_str, args, guard_statement, body_block, return_stmt

    try
        consume!(p, "func")
        name_token = advance!(p)
        name_str = name_token.value
        args = parse_identifier_list!(p)

        # --- THE OPTIONAL GUARD CHECK ---
        guard_statement = nothing
        next_tok = peek_token(p)
        if !isnothing(next_tok) && next_tok.value == "exit"
            guard_statement = parse_exit!(p)
        end

        # 2. Parse the body block (Everything up to the 'return' statement)
        statements = Statement[]
        first_token = peek_token(p)
        line = !isnothing(first_token) ? first_token.line : 1
        col = !isnothing(first_token) ? first_token.col : 1

        while !isnothing(peek_token(p)) && peek_token(p).value != "return"
            push!(statements, parse_statement!(p))
        end

        body_block = StmtBlock(line, col, statements)

        # 3. Strictly enforce the single, final return statement
        final_tok = peek_token(p)
        if isnothing(final_tok) || final_tok.value != "return"
            error("SyntaxError: Malformed function '$name_str': Expected a single 'return' statement at the very end.")
        end

        return_stmt = parse_return!(p)
    finally
        # 4. LOWER THE FLAG: Safely resets context even if parsing fails.
        p.is_inside_function = false
    end

    return FuncStmt(
        start_token.line,
        start_token.col,
        name_str,
        args,
        guard_statement,
        body_block,
        return_stmt
    )
end

function parse_output!(p::Parser)
    start_token = peek_token(p)
    consume!(p, "output")
    expr = parse_expr!(p)
    return OutputStmt(start_token.line, start_token.col, expr)
end

function parse_error!(p::Parser)
    start_token = peek_token(p)
    consume!(p, "error")
    expr = parse_expr!(p)
    return ErrorStmt(start_token.line, start_token.col, expr)
end

function parse_import!(p::Parser)
    start_token = peek_token(p)
    consume!(p, "import")
    filename = parse_identifier!(p)
    return ImportStmt(start_token.line, start_token.col, filename)
end

function parse_return!(p::Parser)
    start_token = peek_token(p)
    consume!(p, "return")
    expr = parse_expr!(p)
    return ReturnStmt(start_token.line, start_token.col, expr)
end

function parse_exit!(p::Parser)
    start_token = peek_token(p)
    consume!(p, "exit")
    expr = parse_expr!(p)

    current_token = peek_token(p)
    if isnothing(current_token) || current_token.value != "when"
        actual = isnothing(current_token) ? "EOF" : current_token.value
        error("SyntaxError: Line $(isnothing(current_token) ? start_token.line : current_token.line), Col $(isnothing(current_token) ? start_token.col : current_token.col): Expected 'when'. Found '$actual'")
    end

    consume!(p, "when")
    cond = parse_expr!(p)

    if isempty(cond.tokens)
        error("SyntaxError: Line $(current_token.line), Col $(current_token.col): 'when' must be followed by a non-empty expression")
    end

    return ExitStmt(start_token.line, start_token.col, cond, expr)
end

# --- UTILITY ELEMENT PARSERS ---

function parse_identifier_list!(p::Parser)
    start_token = peek_token(p)
    identifiers = Identifier[]

    while !isnothing(peek_token(p)) && !(peek_token(p).value in p.identifier_list_terminator)
        push!(identifiers, parse_identifier!(p))
    end

    consume!(p, "as") # Remove the 'as'
    return IdentifierList(start_token.line, start_token.col, identifiers)
end

function parse_identifier!(p::Parser)
    current_token = peek_token(p)
    identifier_token = advance!(p)
    identifier_value = identifier_token.value

    # Check 1: Is it a raw number?
    if all(isdigit, identifier_value)
        error("SyntaxError: Line $(current_token.line), Col $(current_token.col): Invalid identifier '$identifier_value'. Variable names cannot be numeric constants.")
    end

    # Check 2: Is it a reserved language keyword?
    if identifier_value in p.reserved_keywords
        error("SyntaxError: Line $(current_token.line), Col $(current_token.col): Invalid identifier '$identifier_value'. '$identifier_value' is a reserved keyword.")
    end

    return Identifier(current_token.line, current_token.col, identifier_value)
end

function parse_expr!(p::Parser)
    start_token = peek_token(p)
    tokens = ASTNode[] # Uniform array of abstract AST nodes

    while true
        tok = peek_token(p)
        if isnothing(tok) || (tok.value in p.expression_terminator)
            break
        end

        if tok.value == "fn"
            consume!(p, "fn")
            func_name_token = advance!(p)
            # Create the Identifier for the FunctionPointer
            ident = Identifier(func_name_token.line, func_name_token.col, func_name_token.value)
            push!(tokens, FunctionPointer(func_name_token.line, func_name_token.col, ident))
        elseif all(isdigit, tok.value)
            number_token = advance!(p)
            push!(tokens, IntegerNode(number_token.line, number_token.col, parse(Int64, number_token.value)))
        else
            # Instead of pushing a raw Token object, convert it to a valid Identifier node
            # to maintain safe structural alignment inside the AST Node Vector.
            push!(tokens, Identifier(tok.line, tok.col, tok.value))
            advance!(p)
        end
    end

    line = !isnothing(start_token) ? start_token.line : 1
    col = !isnothing(start_token) ? start_token.col : 1

    return Expr(line, col, tokens)
end
