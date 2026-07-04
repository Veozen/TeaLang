# Assuming your other files are structured as modules or included directly:
include("lexer.jl")
include("parser.jl")
include("evaluator.jl")

function run_program(prg::String)
    my_program_tokens = tokenize(prg)
    my_parser = Parser(my_program_tokens)
    my_program_ast = parse_program!(my_parser)

    # Boot interpreter with a fresh, standalone runtime environment
    tea_lang = ASTInterpreter(Environment())
    interpret!(tea_lang, my_program_ast)
end

function run_repl()
    # 1. Instantiate the shared environment outside the loop so state persists
    tea_lang = ASTInterpreter(Environment())

    println("TeaLang Interactive Interpreter!")
    println("Type 'exit' or press Ctrl+C to quit.\n")

    buffer = String[]
    empty_line_count = 0

    while true
        try
            prompt = isempty(buffer) ? "]]] " : "... "
            print(stdout, prompt)
            flush(stdout)

            # Read a line from standard input
            line = readline(stdin)

            # Check if user typed actual characters or hit enter on a blank line
            trimmed_line = strip(line)

            # --- CONSECUTIVE EMPTY LINE CHECKER ---
            if trimmed_line == ""
                if !isempty(buffer) # Only count empty lines if we are building a block
                    empty_line_count += 1

                    # THRESHOLD: 2 consecutive empty lines triggers execution
                    if empty_line_count >= 2
                        combined_code = join(buffer, "\n")
                        empty!(buffer)
                        empty_line_count = 0

                        # Force evaluate the code pool
                        tokens = tokenize(combined_code)
                        my_parser = Parser(tokens)
                        ast = parse_program!(my_parser)

                        interpret!(tea_lang, ast)
                        continue
                    end
                else
                    # If buffer is empty, hitting Enter does nothing
                    continue
                end
            else
                # User typed actual code, reset tracker!
                empty_line_count = 0
            end

            # Standard REPL exit mechanics
            if isempty(buffer) && (lowercase(trimmed_line) == "exit" || lowercase(trimmed_line) == "quit")
                break
            end

            push!(buffer, line)

        catch e
            # Catch compilation/runtime errors gracefully so the REPL doesn't crash!
            if isa(e, InterruptException)
                # This catches Ctrl+C natively in Julia
                println(stdout, "\nGoodbye!")
                break
            elseif isa(e, EOFError)
                # This catches Ctrl+D (End of File) natively
                println(stdout, "\nGoodbye!")
                break
            else
                # Print interpreter errors to standard error stream
                println(stderr, e)
                empty!(buffer)
                empty_line_count = 0
            end
        end
    end
end
