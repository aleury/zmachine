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
    next_pos: usize,
    char: u8,

    fn init(input: []const u8) Lexer {
        return Lexer{
            .input = input,
            .pos = 0,
            .next_pos = 1,
            .char = input[0],
        };
    }
};

fn next_token(lexer: *Lexer) !Token {
    skip_whitespace(lexer);
    switch (lexer.char) {
        ',' => {
            read_char(lexer);
            return Token.comma;
        },
        'a'...'z' => {
            const ident = read_identifier(lexer);
            return lookup_identifier(ident);
        },
        '0'...'9' => {
            const value = try read_number(lexer);
            return Token{ .number = value };
        },
        0 => return Token.eof,
        else => return Token.illegal,
    }
}

fn lookup_identifier(ident: []const u8) Token {
    const map = std.StaticStringMap(Token).initComptime(.{
        .{ "a0", Token{ .register = Reg.a0 } },
        .{ "li", Token{ .opcode = "li" } },
    });
    return map.get(ident) orelse Token{ .ident = ident };
}

fn read_number(lexer: *Lexer) !u32 {
    const start = lexer.pos;
    while (is_digit(lexer.char)) {
        read_char(lexer);
    }
    const str = lexer.input[start..lexer.pos];
    return try std.fmt.parseUnsigned(u32, str, 10);
}

fn read_identifier(lexer: *Lexer) []const u8 {
    const start = lexer.pos;
    while (is_alphanumeric(lexer.char)) {
        read_char(lexer);
    }
    return lexer.input[start..lexer.pos];
}

fn read_char(lexer: *Lexer) void {
    lexer.char = peek_char(lexer);
    lexer.pos = lexer.next_pos;
    lexer.next_pos += 1;
}

fn peek_char(lexer: *Lexer) u8 {
    if (lexer.next_pos >= lexer.input.len) {
        return 0;
    }
    return lexer.input[lexer.next_pos];
}

fn is_digit(c: u8) bool {
    return std.ascii.isDigit(c);
}

fn is_alphanumeric(c: u8) bool {
    return std.ascii.isAlphanumeric(c);
}

fn skip_whitespace(lexer: *Lexer) void {
    while (std.ascii.isWhitespace(lexer.char)) {
        read_char(lexer);
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
    for (&tokens) |*token| {
        token.* = try next_token(&lexer);
    }

    try expectEqualSlices(Token, &expected, &tokens);
}
