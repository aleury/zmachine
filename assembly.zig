const std = @import("std");
const activeTag = std.meta.activeTag;
const expectEqualSlices = std.testing.expectEqualSlices;

const Reg = enum {
    a0,
};

const Token = union(enum) {
    eof,
    illegal,

    // Punctuation
    comma,

    // Literals
    ident: []const u8,
    opcode: []const u8,
    register: Reg,
    number: u32,

    pub fn equals(self: Token, other: Token) bool {
        // First check if the tags match
        if (activeTag(self) != activeTag(other)) {
            return false;
        }

        // Then check if the values match
        return switch (self) {
            // Simple tokens automatically match if the tags match.
            .eof, .illegal, .comma => true,

            // For complex tokens, we need to compare the values.
            .ident => |ident| std.mem.eql(u8, ident, other.ident),
            .opcode => |opcode| std.mem.eql(u8, opcode, other.opcode),
            .register => |register| register == other.register,
            .number => |number| number == other.number,
        };
    }
};

const Lexer = struct {
    input: []const u8,
    pos: usize,
    nextPos: usize,
    char: u8,

    fn init(input: []const u8) Lexer {
        return Lexer{
            .input = input,
            .pos = 0,
            .nextPos = 1,
            .char = input[0],
        };
    }
};

fn nextToken(lexer: *Lexer) !Token {
    while (true) {
        skipWhitespace(lexer);
        switch (lexer.char) {
            ',' => {
                readChar(lexer);
                return Token.comma;
            },
            'a'...'z' => {
                const start = lexer.pos;
                while (std.ascii.isAlphanumeric(lexer.char)) {
                    readChar(lexer);
                }
                return lookupIdentifier(lexer.input[start..lexer.pos]);
            },
            '0'...'9' => {
                const start = lexer.pos;
                while (std.ascii.isDigit(lexer.char)) {
                    readChar(lexer);
                }
                const str = lexer.input[start..lexer.pos];
                const value = try std.fmt.parseUnsigned(u32, str, 10);
                return Token{ .number = value };
            },
            0 => return Token.eof,
            else => return Token.illegal,
        }
    }
}

fn lookupIdentifier(ident: []const u8) Token {
    if (std.mem.eql(u8, ident, "a0")) return Token{ .register = Reg.a0 };
    if (std.mem.eql(u8, ident, "li")) return Token{ .opcode = "li" };
    return Token{ .ident = ident };
}

fn readChar(lexer: *Lexer) void {
    lexer.char = peekChar(lexer);
    lexer.pos = lexer.nextPos;
    lexer.nextPos += 1;
}

fn peekChar(lexer: *Lexer) u8 {
    if (lexer.nextPos >= lexer.input.len) {
        return 0;
    }
    return lexer.input[lexer.nextPos];
}

fn skipWhitespace(lexer: *Lexer) void {
    while (std.ascii.isWhitespace(lexer.char)) {
        readChar(lexer);
    }
}

test "lexer tokenizes 'li a0, 1'" {
    const input = "li a0, 1";
    const expected = [_]Token{
        Token{ .opcode = "li" },
        Token{ .register = Reg.a0 },
        Token.comma,
        Token{ .number = 1 },
        Token.eof,
    };

    var lexer = Lexer.init(input);
    var tokens: [expected.len]Token = undefined;

    for (0..tokens.len) |i| {
        tokens[i] = try nextToken(&lexer);
    }

    try expectEqualSlices(Token, &expected, &tokens);
}
