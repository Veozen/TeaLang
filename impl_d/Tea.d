import std.stdio;
import std.file;
import std.getopt;
import std.string;
import std.exception;
import core.stdc.stdlib : exit;
import std.path : baseName;

import repl;

void runScriptFile(string filePath) {
    if (!exists(filePath)) {
        stderr.writeln("Error: The file '" ~ filePath ~ "' does not exist.");
        exit(1);
    }

    try {
        auto source = readText(filePath);
        runProgram(source);
        writeln("[" ~ baseName(filePath) ~ "] Executed successfully.");
    }
    catch (Exception e) {
        stderr.writeln("Runtime Error in " ~ filePath ~ ": " ~ e.msg);
        exit(1);
    }
}

void main(string[] args) {
    bool replMode = false;
    string scriptFile;

    // Equivalent to Python argparse + mutually exclusive group
    getopt(
        args,
        config.passThrough,
        "repl", &replMode,
        "script", &scriptFile
    );

    // Enforce mutual exclusivity
    if (!replMode && scriptFile.length == 0) {
        stderr.writeln("Error: You must specify either --repl or --script=<file>.");
        exit(1);
    }
    if (replMode && scriptFile.length > 0) {
        stderr.writeln("Error: --repl and --script cannot be used together.");
        exit(1);
    }

    if (replMode) {
        runRepl();
    } else {
        runScriptFile(scriptFile);
    }
}
