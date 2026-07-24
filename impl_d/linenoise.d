module linenoise;

import core.sys.posix.termios;
import core.sys.posix.unistd;
import core.sys.posix.sys.ioctl;
import std.stdio;
import std.string;
import std.conv;
import std.array;

private {
    termios orig_termios;
    bool rawmode = false;
    string[] history;
    int history_max_len = 100;
}

// Enable raw mode (turn off canonical mode & echo)
private int enableRawMode(int fd) {
    termios raw;
    if (!isatty(fd)) return -1;
    if (tcgetattr(fd, &orig_termios) == -1) return -1;

    raw = orig_termios;
    raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
    raw.c_oflag &= ~(OPOST);
    raw.c_cflag |= (CS8);
    raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
    raw.c_cc[VMIN] = 1;
    raw.c_cc[VTIME] = 0;

    if (tcsetattr(fd, TCSAFLUSH, &raw) < 0) return -1;
    rawmode = true;
    return 0;
}

// Restore original terminal attributes
private void disableRawMode(int fd) {
    if (rawmode) {
        tcsetattr(fd, TCSAFLUSH, &orig_termios);
        rawmode = false;
    }
}

public void linenoiseHistoryAdd(string line) {
    if (line.length == 0) return;
    history ~= line;
    if (history.length > history_max_len) {
        history = history[1 .. $];
    }
}

public void linenoiseHistorySetMaxLen(int len) {
    history_max_len = len;
}

// Pure D implementation of linenoise prompt loop
public string linenoise(string prompt) {
    int fd = STDIN_FILENO;

    if (enableRawMode(fd) == -1) {
        // Fallback if not a TTY
        write(prompt);
        stdout.flush();
        return readln().stripRight("\r\n");
    }

    scope(exit) disableRawMode(fd);

    write(prompt);
    stdout.flush();

    char[] buf;
    int pos = 0;
    int history_index = cast(int)history.length;

    while (true) {
        char c;
        auto nread = read(fd, &c, 1);
        if (nread <= 0) break;


        // Handle Return / Enter
        if (c == '\r' || c == '\n') {
            write("\r\n"); // Changed from writeln();
            stdout.flush();
            return buf.idup;
        }
        // Handle Ctrl+C or Ctrl+D
        else if (c == 3 || c == 4) {
            write("\r\n"); // Changed from writeln();
            stdout.flush();
            return null;
        }
        // Handle Ctrl+C or Ctrl+D
        else if (c == 3 || c == 4) {
            writeln();
            return null;
        }
        // Handle Backspace
        else if (c == 127 || c == 8) {
            if (buf.length > 0) {
                buf = buf[0 .. $-1];
                // Erase character on screen
                write("\b \b");
                stdout.flush();
            }
        }
        // Handle Escape Sequences (Arrow keys)
        else if (c == 27) {
            char[2] seq;
            if (read(fd, &seq[0], 1) == 1 && read(fd, &seq[1], 1) == 1) {
                if (seq[0] == '[') {
                    // UP ARROW: History Backwards
                    if (seq[1] == 'A') {
                        if (history_index > 0 && history.length > 0) {
                            history_index--;
                            // Clear line on terminal
                            writef("\r\033[K%s%s", prompt, history[history_index]);
                            stdout.flush();
                            buf = history[history_index].dup;
                        }
                    }
                    // DOWN ARROW: History Forwards
                    else if (seq[1] == 'B') {
                        if (history_index < cast(int)history.length - 1) {
                            history_index++;
                            writef("\r\033[K%s%s", prompt, history[history_index]);
                            stdout.flush();
                            buf = history[history_index].dup;
                        } else if (history_index == history.length - 1) {
                            history_index++;
                            writef("\r\033[K%s", prompt);
                            stdout.flush();
                            buf.length = 0;
                        }
                    }
                }
            }
        }
        // Printable ASCII characters
        else if (c >= 32 && c <= 126) {
            buf ~= c;
            write(c);
            stdout.flush();
        }
    }

    return buf.idup;
}
