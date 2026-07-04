# 1. Equivalent to Python's @dataclass
struct Token
    value::String
    line::Int
    col::Int
    is_string::Bool

    # Inner constructor to allow default arguments like Python
    function Token(value::String="", line::Int=0, col::Int=0, is_string::Bool=false)
        new(value, line, col, is_string)
    end
end

# Custom string representation (Equivalent to __repr__)
function Base.show(io::IO, t::Token)
    print(io, "Token($(repr(t.value)), L:$(t.line), C:$(t.col), S:$(t.is_string))")
end

function tokenize(source::String)
    tokens = Token[]
    line, col = 1, 1

    # In Julia, we use byte indices to traverse strings safely
    i = 1
    len = lastindex(source)

    while i <= len
        char = source[i]

        # 1. Handle Whitespace & Line Breaks
        if isspace(char)
            if char == '\n'
                line += 1
                col = 1
            else
                col += 1
            end
            i = nextind(source, i)
            continue
        end

        # 2. Handle Comments
        if char == '#'
            while i <= len && source[i] != '\n'
                i = nextind(source, i)
            end
            continue
        end

        # 3. Handle Strings (Quotes)
        if char == '"'
            start_col = col
            i = nextind(source, i) # skip opening quote
            col += 1

            # Using an IOBuffer is Julia's high-performance equivalent
            # to building an array of characters and doing "".join()
            content = IOBuffer()

            while i <= len && source[i] != '"'
                if source[i] == '\n' # Support multi-line strings!
                    line += 1
                    col = 1
                else
                    col += 1
                end
                write(content, source[i])
                i = nextind(source, i)
            end

            push!(tokens, Token(String(take!(content)), line, start_col, true))
            i = nextind(source, i) # skip closing quote
            col += 1
            continue
        end

        # 4. Handle Semicolon (Self-terminating Token)
        if char == ';'
            push!(tokens, Token(";", line, col))
            i = nextind(source, i)
            col += 1
            continue
        end

        # 5. Handle Normal Words (Identifiers/Keywords/Numbers)
        start_col = col
        word = IOBuffer()

        while i <= len && !isspace(source[i]) && !occursin(source[i], ";\"#")
            write(word, source[i])
            i = nextind(source, i)
            col += 1
        end

        word_str = String(take!(word))
        if !isempty(word_str)
            push!(tokens, Token(word_str, line, start_col))
        end
    end

    return tokens
end
