// lexer.d
module lexer;

import std.stdio;
import std.string;
import std.array;
import std.uni;
import std.conv : to;
import std.algorithm.searching : canFind;


struct Token {
    string value;
    int line;
    int col;
    bool isString;

    string toString() const {
        return "Token(" ~ value ~
               ", L:" ~ line.to!string ~
               ", C:" ~ col.to!string ~
               ", S:" ~ (isString ? "true" : "false") ~ ")";
    }
}

Token[] tokenize(string source)
{
    Token[] tokens;
    int line = 1;
    int col = 1;
    size_t i = 0;

    while (i < source.length)
    {
        dchar c = source[i];

        // 1. Whitespace
        if (c.isWhite)
        {
            if (c == '\n')
            {
                line++;
                col = 1;
            }
            else col++;

            i++;
            continue;
        }

        // 2. Comments (# until newline)
        if (c == '#')
        {
            while (i < source.length && source[i] != '\n')
                i++;
            continue;
        }

        // 3. Strings
        if (c == '"')
        {
            int startCol = col;
            i++; col++; // skip opening quote

            auto content = appender!string();

            while (i < source.length && source[i] != '"')
            {
                if (source[i] == '\n')
                {
                    line++;
                    col = 1;
                }
                else col++;

                content.put(source[i]);
                i++;
            }

            // skip closing quote
            if (i < source.length)
            {
                i++;
                col++;
            }

            tokens ~= Token(content.data, line, startCol, true);
            continue;
        }

        // 4. Semicolon
        if (c == ';')
        {
            tokens ~= Token(";", line, col, false);
            i++; col++;
            continue;
        }

        // 5. Words
        int startCol = col;
        auto word = appender!string();

        while (i < source.length &&
               !source[i].isWhite &&
               !canFind("\"#;", source[i]))
        {
            word.put(source[i]);
            i++;
            col++;
        }

        if (word.data.length)
            tokens ~= Token(word.data, line, startCol, false);
    }

    return tokens;
}
