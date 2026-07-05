# 1. Bring in your project files (uncomment depending on your setup)
include("repl.jl")

# 2. Use the standard ArgParse package for CLI control
using ArgParse

function run_script_file(file_path::String)
    # Native alternative to os.path.exists()
    if !isfile(file_path)
        println(stderr, "Error: The file '$file_path' does not exist.")
        exit(1)
    end

    try
        # Reads the whole file as a clean UTF-8 string instantly
        source_code = read(file_path, String)
        run_program(source_code)

        # basename() extracts just the file name out of a long path string
        println("[", basename(file_path), "] Executed successfully.")

    catch e
        println(stderr, "Runtime Error in $file_path: $e")
        exit(1)
    end
end

function main()
    # Configuration settings for your argument parser
    s = ArgParseSettings(description = "Interpreter pipeline for Tea.")

    @add_arg_table! s begin
        "script"
            help = "Path to an .tea source script file to compile and execute."
            required = false
        "--repl"
            help = "Launches the live interactive execution console (REPL)."
            action = :store_true
    end

    parsed_args = parse_args(ARGS, s)

    # --- MUTUAL EXCLUSION & ROUTING CHECK ---
    # Because ArgParse doesn't have a direct "add_mutually_exclusive_group" function,
    # we evaluate the combinations manually with a crisp, clear if-statement constraint:
    has_repl = parsed_args["repl"]
    script_path = parsed_args["script"]

    if has_repl && !isnothing(script_path)
        println(stderr, "Error: Cannot provide a script file path while activating the --repl flag.")
        exit(1)
    elseif !has_repl && isnothing(script_path)
        println(stderr, "Error: Please specify either a script file path or use --repl.")
        exit(1)
    end

    # Route execution flow based on user CLI invocation flags
    if has_repl
        run_repl()
    elseif !isnothing(script_path)
        run_script_file(script_path)
    end
end

# In Julia, scripts run sequentially. To make a clean entry point wrapper
# exactly equivalent to `if __name__ == "__main__":`, we check if the file
# is being run directly from the command line interface:
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
