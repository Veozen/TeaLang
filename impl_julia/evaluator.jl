# 1. Define the Mutable Environment Context
mutable struct Environment
    scopes::Vector{Dict{String, Int64}}
    functions::Dict{String, FuncStmt}
    function_ids::Vector{String}

    # Custom constructor equivalent to Python's __init__
    function Environment()
        new(
            [Dict{String, Int64}()], # Start with one default root scope dictionary
            Dict{String, FuncStmt}(), # Empty function mapping registry
            String["+", "-", "*", "/", "mod", "<", ">", "<=", ">=", "=", "peek", "extract", "exchange"]
        )
    end
end

# --- SCOPE MANAGEMENT METHODS ---

function push_scope!(env::Environment, bindings::Dict{String, Int64})
    push!(env.scopes, bindings)
end

function pop_scope!(env::Environment)
    if length(env.scopes) > 1  # Protect the root scope from being destroyed
        pop!(env.scopes)
    end
end

function get_variable_value(env::Environment, name::String)
    # env.scopes[end] targets the immediate active scope frame at the top of the stack
    active_scope = env.scopes[end]
    if haskey(active_scope, name)
        return active_scope[name]
    else
        error("NameError: Runtime Error: Variable '$name' is not defined in this scope.")
    end
end

# --- FUNCTION REGISTRY METHODS ---

function define_function!(env::Environment, name::String, node::FuncStmt)
    if !(name in env.function_ids)
        push!(env.function_ids, name) # Assigns a new unique integer index
    end
    env.functions[name] = node
end

function get_name_by_id(env::Environment, func_id::Int)
    # Convert 0-based Python indexing to Julia's 1-based array indexing
    julia_idx = func_id + 1

    if 1 <= julia_idx <= length(env.function_ids)
        return env.function_ids[julia_idx]
    else
        error("IndexError: Runtime Error: Invalid function ID $func_id")
    end
end

function get_id_by_name(env::Environment, func_name::String)
    # findfirst returns the 1-based index where the value matches, or 'nothing'
    idx = findfirst(==(func_name), env.function_ids)

    if isnothing(idx)
        error("NameError: Runtime Error: function $func_name is not defined")
    else
        # Convert back to 0-based index to maintain spec compatibility with Python
        return idx - 1
    end
end


# 1. Define the Evaluator Context Structure
struct RPNEvaluator
    env::Environment
end

# 2. Main RPN Stream Processor
function evaluate_expr!(evaluator::RPNEvaluator, expr_node::Expr, stack::Union{Nothing, Vector{Int64}}=nothing)
    # If no stack is passed from a parent call, initialize a fresh one
    if isnothing(stack)
        stack = Int64[]
    end

    for token in expr_node.tokens
        # Check explicit node types using 'isa' via Multiple Dispatch routing
        if isa(token, IntegerNode)
            push!(stack, token.value)
            continue
        elseif isa(token, FunctionPointer)
            # func_name is an Identifier node in our Julia AST, extract string via .name
            func_name = token.name.name
            func_id = get_id_by_name(evaluator.env, func_name)
            push!(stack, func_id)
            continue
        elseif isa(token, Identifier)
            tok = token.name
        else
            # Fallback if processing a raw string or Token structure
            tok = hasproperty(token, :value) ? token.value : string(token)
        end

        # --- KEYWORD AND OPERATOR ROUTING ENGINE ---

        if tok == "input"
            print(stdout, "?")
            flush(stdout) # Ensure output displays in terminal instantly

            user_line = readline(stdin)
            user_line = strip(user_line)

            try
                push!(stack, parse(Int64, user_line))
            catch e
                if isa(e, ArgumentError) # Julia throws ArgumentError on failed numeric parse
                    error("TypeError: Runtime Error: 'input' expected an integer, but got '$user_line'")
                else
                    rethrow(e)
                end
            end

        elseif tok == "depth"
            active_scope = evaluator.env.scopes[end]
            if haskey(active_scope, "depth")
                push!(stack, active_scope["depth"])
            else
                push!(stack, 0) # Fallback default outside function bounds
            end

        elseif tok == "apply"
            if isempty(stack)
                error("Runtime Error: Stack empty during 'apply' instruction")
            end
            func_id = pop!(stack)

            # Translate integer index -> string name -> AST branch
            func_name = get_name_by_id(evaluator.env, func_id)

            if func_name in ["+", "-", "*", "/", "mod", "<", ">", "<=", ">=", "=", "peek", "extract", "exchange"]
                # Look up the interpreter globally or create runtime binding links
                # We can handle the evaluation using our previously defined operator engine
                # passing a dummy/placeholder reference or adjusting your call parameters:
                execute_operator!(ASTInterpreter(evaluator.env), func_name, stack)
            else
                func_obj = evaluator.env.functions[func_name]
                execute_user_function!(ASTInterpreter(evaluator.env), func_obj, stack)
            end

        elseif haskey(evaluator.env.functions, tok)
            func_obj = evaluator.env.functions[tok]
            execute_user_function!(ASTInterpreter(evaluator.env), func_obj, stack)

        elseif !isempty(evaluator.env.scopes) && haskey(evaluator.env.scopes[end], tok)
            val = get_variable_value(evaluator.env, tok)
            push!(stack, val)

        elseif tok in ["+", "-", "*", "/", "mod", "<", ">", "<=", ">=", "=", "peek", "extract", "exchange"]
            execute_operator!(ASTInterpreter(evaluator.env), tok, stack)

        else
            error("NameError: Runtime Error: Unknown operator or symbol '$tok'")
        end
    end

    # Return a copy of the stack elements to prevent mutability leaks
    # (Equivalent to Python's list(stack))
    return copy(stack)
end





# 1. Define your interpreter structure
struct ASTInterpreter
    env::Environment
    evaluator::RPNEvaluator

    function ASTInterpreter(environment::Environment)
        # We initialize the evaluator directly with the environment context.
        # No callbacks are required; the evaluator can just call the global
        # functions execute_user_function! or execute_operator! when needed.
        new(environment, RPNEvaluator(environment))
    end
end

# 2. Main entry point method
function interpret!(interp::ASTInterpreter, program::Program)
    execute_statements!(interp, program.body)
end

# 3. Handle a Block of Statements (sequential fallback)
function execute_statements!(interp::ASTInterpreter, node::StmtBlock)
    for stmt in node.statements
        execute_statements!(interp, stmt)
    end
end

# 4. Handle 'SetStmt' (Variable Assignment)
function execute_statements!(interp::ASTInterpreter, node::SetStmt)
    # 1. Ask the RPN engine to compute the expression
    stack_results = evaluate_expr!(interp.evaluator, node.expr)
    identifiers = node.identifiers.identifiers

    for (i, var_node) in enumerate(identifiers)
        var_name = var_node.name

        # Safety check: make sure the stack actually gave us enough values!
        if i <= length(stack_results)
            # In Julia, we access the top/active scope frame at the end of our scope vector
            interp.env.scopes[end][var_name] = stack_results[i]
        else
            error("Runtime Error: Not enough values on the stack to assign to '$var_name'.")
        end
    end
end

# 5. Handle 'FuncStmt' (Function Registration)
function execute_statements!(interp::ASTInterpreter, node::FuncStmt)
    # node.name is already parsed as a String in your Julia AST design!
    function_name_string = node.name
    interp.env.functions[function_name_string] = node
    push!(interp.env.function_ids, function_name_string)
end

# 6. Handle 'OutputStmt' (Standard Output Stream)
function execute_statements!(interp::ASTInterpreter, node::OutputStmt)
    stack_results = evaluate_expr!(interp.evaluator, node.expr)
    # Join values with spaces and print directly to standard out
    println(stdout, join(string.(stack_results), " "))
end

# 7. Handle 'ErrorStmt' (Standard Error Stream)
function execute_statements!(interp::ASTInterpreter, node::ErrorStmt)
    stack_results = evaluate_expr!(interp.evaluator, node.expr)
    # Print explicitly to stderr
    println(stderr, "Error: ", join(string.(stack_results), " "))
end

# 8. Handle 'ImportStmt' (Module / Function Scraping)
function execute_statements!(interp::ASTInterpreter, node::ImportStmt)
    filename = node.filename.name

    try
        # 2. Parse the target file into its own independent AST block
        imported_ast = parse_file_to_ast(filename)

        # 3. Look through the statements inside the imported file's body
        for sub_node in imported_ast.body.statements
            # 4. SCRAPE ONLY FUNCTIONS via structural checking
            if isa(sub_node, FuncStmt)
                func_name = sub_node.name
                interp.env.functions[func_name] = sub_node
            end
        end
    catch e
        if isa(e, SystemError) # Julia's file missing exception
            error("Runtime Error: Could not find imported file '$filename'")
        else
            rethrow(e) # Pass along any internal code syntax bugs
        end
    end
end

function execute_operator!(interp::ASTInterpreter, operator::String, stack::Vector{Int64})
    if length(stack) < 2
        error("Runtime Error: Stack underflow before executing operator '$operator'")
    end

    # Pop the top two elements
    b = pop!(stack)
    a = pop!(stack)

    if operator == "+"
        push!(stack, a + b)
    elseif operator == "-"
        push!(stack, a - b)
    elseif operator == "*"
        push!(stack, a * b)
    elseif operator == "/"
        push!(stack, div(a, b)) # div() is Julia's integer truncating division (a // b in Python)
    elseif operator == "mod"
        push!(stack, rem(a, b)) # rem() matches Python's modulo behavior for integers
    elseif operator == "<"
        push!(stack, a < b ? 1 : 0)
    elseif operator == ">"
        push!(stack, a > b ? 1 : 0)
    elseif operator == "<="
        push!(stack, a <= b ? 1 : 0)
    elseif operator == ">="
        push!(stack, a >= b ? 1 : 0)
    elseif operator == "="
        push!(stack, a == b ? 1 : 0)

    elseif operator == "peek"
        push!(stack, a) # Put 'a' back on the stack
        index = b       # Relative index

        # 1-Based Position Calculation:
        # Python: len(stack) - 1 - index
        # Julia: length(stack) - index
        target_position = length(stack) - index

        if target_position < 1
            error("Runtime Error: Stack underflow during peek operation")
        end

        push!(stack, stack[target_position])

    elseif operator == "extract"
        push!(stack, a) # Put 'a' back on the stack
        index = b

        target_position = length(stack) - index

        if target_position < 1
            error("Runtime Error: Stack underflow during extract operation")
        end

        value = splice!(stack, target_position) # splice! removes and returns the item at index
        push!(stack, value)

    elseif operator == "exchange"
        push!(stack, a) # Put 'a' back on the stack
        index = b

        target_position = length(stack) - index

        if target_position < 1
            error("Runtime Error: Stack underflow during exchange operation")
        end

        # In-place elegant swap syntax in Julia
        stack[target_position], stack[end] = stack[end], stack[target_position]

    else
        # Unrecognized operator recovery
        push!(stack, a)
        push!(stack, b)
        error("ValueError: Unknown operator: $operator")
    end
end

function execute_user_function!(interp::ASTInterpreter, func_node::FuncStmt, current_stack::Vector{Int64})
    # 1. Capture the exact stack depth BEFORE argument consumption
    calling_depth = length(current_stack)

    func_node_args = func_node.args.identifiers
    num_args = length(func_node_args)

    if length(current_stack) < num_args
        error("Runtime Error: Not enough arguments on stack for function '$(func_node.name)'")
    end

    # Pop arguments from the stack.
    # Python's [pop() for _ in...][::-1] reverses the popped items to match original order.
    # In Julia, we can collect them directly in correct order by extracting backwards:
    args = Vector{Int64}(undef, num_args)
    for i in num_args:-1:1
        args[i] = pop!(current_stack)
    end

    # 2. Map parameter names to values into a Dict
    local_bindings = Dict{String, Int64}()
    for (i, arg_node) in enumerate(func_node_args)
        local_bindings[arg_node.name] = args[i]
    end

    # 3. Inject 'depth' variable safely
    local_bindings["depth"] = calling_depth

    # 4. Push new scope frame onto environment stack
    push_scope!(interp.env, local_bindings)

    try
        # 5. Handle Optional Guard
        if !isnothing(func_node.exit_stmt)
            cond_result = evaluate_expr!(interp.evaluator, func_node.exit_stmt.condition, current_stack)
            if !isempty(cond_result) && cond_result[end] != 0
                evaluate_expr!(interp.evaluator, func_node.exit_stmt.expr, current_stack)
                return nothing # Early guard exit!
            end
        end

        # 6. Run the function body statements
        execute_statements!(interp, func_node.body_stmt)

        # 7. Run the mandatory final return statement expression
        evaluate_expr!(interp.evaluator, func_node.return_stmt.expr, current_stack)
        return nothing

    finally
        # 8. Collapse the scope frame safely no matter what happens
        pop_scope!(interp.env)
    end
end

        # 1. Tail Call Analyzer
function is_tail_call(interp::ASTInterpreter, expr_node::Expr)
    # Checks if the expression stream contains tokens
    if length(expr_node.tokens) >= 1
        first_token = expr_node.tokens[1]

        # In our Julia AST design, the token is either an Identifier or a FunctionPointer.
        # We can use 'isa' to check if it has a 'name' field, or check its type.
        token_str = ""
        if isa(first_token, Identifier)
            token_str = first_token.name
        elseif isa(first_token, FunctionPointer)
            token_str = first_token.name.name
        else
            # Fallback if it's a raw Token struct or string literal
            token_str = hasproperty(first_token, :value) ? first_token.value : string(first_token)
        end

        # If the string matches a registered user function, return its node block
        if haskey(interp.env.functions, token_str)
            return interp.env.functions[token_str]
        end
    end
    return nothing
end

# 2. File to AST Driver Utility
function parse_file_to_ast(filepath::String)
    if !isfile(filepath)
        error("SystemError: Could not open file at '$filepath'")
    end

    # Read the whole file context directly into a high-speed string buffer.
    # Since our Julia 'tokenize' function handles line numbers perfectly,
    # we don't need to manually slice it by line loops!
    source_content = read(filepath, String)

    # 1. Run the Julia Lexer
    file_tokens = tokenize(source_content)

    # 2. Spin up the Parser and compile the Program node tree
    parser_instance = Parser(file_tokens)
    return parse_program!(parser_instance)
end
