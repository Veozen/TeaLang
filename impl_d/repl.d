//repl.d
module repl;

import std.stdio;
import std.string;
import std.string : toStringz;
import std.array;
import std.exception;
import std.algorithm;
import std.conv : to;
import lexer;
import parser;
import evaluator;
import linenoise; // Imports impl_d/linenoise.d directly


void runProgram(string prg) {
    auto tokens = tokenize(prg);
    auto parser = new Parser(tokens);
    auto ast    = parser.parseProgram();

    auto tea = new ASTInterpreter(new Environment());
    tea.interpret(ast);
}

void runRepl() {
    auto tea = new ASTInterpreter(new Environment());

    writeln("TeaLang Interactive Interpreter!");
    writeln("Type 'exit' or press Ctrl+C to quit.\n");

    // Enable history so UP/DOWN arrows work
    linenoiseHistorySetMaxLen(100);

    string[] buffer;
    int emptyLineCount = 0;

    while (true) {
        try {
            string prompt = buffer.length == 0 ? "Tea> " : "... ";
            // std.stdio.write(prompt);
            // string line = std.stdio.readln();

            string line = linenoise.linenoise(prompt);

            if (line.length > 0) {
                linenoiseHistoryAdd(line);
            }

            // Trim only for logic, not for buffer storage
            string trimmed = line.strip();

            // Empty line logic
            if (trimmed.length == 0) {
                if (buffer.length > 0) {
                    emptyLineCount++;
                    if (emptyLineCount >= 2) {
                        auto combined = buffer.join("\n");
                        buffer.length = 0;
                        emptyLineCount = 0;

                        auto tokens = tokenize(combined);
                        auto parser = new Parser(tokens);
                        auto ast    = parser.parseProgram();
                        tea.interpret(ast);
                    }
                }
                continue;
            } else {
                emptyLineCount = 0;
            }

            // Exit command
            if (buffer.length == 0 &&
                (trimmed == "exit" || trimmed == "quit"))
            {
                break;
            }

            buffer ~= line;

        } catch (Exception e) {
            stderr.writeln(e.msg);
            buffer.length = 0;
            emptyLineCount = 0;
        } catch (Throwable t) {
            stderr.writeln("Error: "~t.msg);
            buffer.length = 0;
            emptyLineCount = 0;
        }
    }
}
