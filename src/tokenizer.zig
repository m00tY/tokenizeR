const std = @import("std");
const log = @import("log");
const CommentedToken = @import("tokens.zig").CommentedToken;
const Token = @import("tokens.zig").Token;
const Special = @import("tokens.zig").Special;
const Lambda = @import("tokens.zig").Lambda;
const LiteralType = enum {
    Bool,
    Null,
    Integer,
    Float,
    String,
    Symbol,
};

const EOF = Token.EOF;
const Newline = Token.Newline;
const Semicolon = Token.Semicolon;
const Comma = Token.Comma;
const LParen = Token.LParen;
const RParen = Token.RParen;
const LBrace = Token.LBrace;
const RBrace = Token.RBrace;
const LBracket = Token.LBracket;
const RBracket = Token.RBracket;
const Literal = Token.Literal;
const Symbol = Token.Symbol;
const Help = Token.Help;
const LAssign = Token.LAssign;
const LowerEqual = Token.LowerEqual;
const SuperAssign = Token.SuperAssign;
const LowerThan = Token.LowerThan;
const GreaterEqual = Token.GreaterEqual;
const GreaterThan = Token.GreaterThan;
const Or = Token.Or;
const Pipe = Token.Pipe;
const VectorizedOr = Token.VectorizedOr;
const And = Token.And;
const VectorizedAnd = Token.VectorizedAnd;
const Equal = Token.Equal;
const OldAssign = Token.OldAssign;
const Dollar = Token.Dollar;
const RAssign = Token.RAssign;
const Minus = Token.Minus;
const NotEqual = Token.NotEqual;
const UnaryNot = Token.UnaryNot;
const Tilde = Token.Tilde;
const Slot = Token.Slot;
const NsGetInt = Token.NsGetInt;
const NsGet = Token.NsGet;
const ColonAssign = Token.ColonAssign;
const Colon = Token.Colon;
const Power = Token.Power;
const Multiply = Token.Multiply;
const Divide = Token.Divide;
const Plus = Token.Plus;
const Modulo = Token.Modulo;
const Function = Token.Function;
const Continue = Token.Continue;
const Break = Token.Break;
const For = Token.For;
const If = Token.If;
const Else = Token.Else;
const In = Token.In;
const While = Token.While;
const Repeat = Token.Repeat;

const SYMBOL_ENDING = [_]u8{ ' ', '(', ')', '{', '}', '#', ';', '\n', '\t', '\r', '+', '-', '/', '\\', '%', '*', '^', '!', '&', '|', '<', '>', '=', ',', '[', ']', '$', '`', '"' };

// Generic Iterator
pub const Iterator = struct {
    data: []const u8,
    it: usize,

    pub fn init(data: []const u8) Iterator {
        return Iterator{ .data = data, .it = 0 };
    }

    pub fn next(self: *Iterator) u8 {
        if (self.it < self.data.len) {
            const char = self.data[self.it];
            self.it += 1;
            return char;
        }
        return 0; // EOF
    }

    pub fn peek(self: *Iterator) u8 {
        if (self.it < self.data.len) {
            return self.data[self.it];
        }
        return 0; // EOF
    }

    pub fn has_next(self: *Iterator) bool {
        return self.it < self.data.len;
    }
};

// Tokenizer using Iterator
pub const Tokenizer = struct {
    offset: usize,
    it: Iterator, // Mutable iterator
    current_char: u8,
    raw_source: []const u8,
    allocator: std.mem.Allocator,
    tokens: std.ArrayList(CommentedToken),

    pub fn init(input: []const u8, allocator: std.mem.Allocator) Tokenizer {
        const it = Iterator.init(input);
        const tokens = std.ArrayList(CommentedToken).init(allocator);
        return Tokenizer{
            .offset = 0,
            .it = it,
            .current_char = '\\',
            .raw_source = input,
            .allocator = allocator,
            .tokens = tokens,
        };
    }

    pub fn tokenize(self: *Tokenizer) []CommentedToken {
        var tokens = std.ArrayList(CommentedToken).init(self.allocator);
        self.next();
        while (self.it.has_next()) { // Now 'it' can be mutated
            switch (self.current_char) {
                ' ' | '\t' => self.next(),
                '\r' => {
                    self.next();
                    self.push_token(Newline, &tokens);
                    self.next();
                },
                '\n' => {
                    self.push_token(Newline, &tokens);
                    self.next();
                },
                ';' => {
                    self.push_token(Semicolon, &tokens);
                    self.next();
                },
                ',' => {
                    self.push_token(Comma, &tokens);
                    self.next();
                },
                '(' => {
                    self.push_token(LParen, &tokens);
                    self.next();
                },
                ')' => {
                    self.push_token(RParen, &tokens);
                    self.next();
                },
                '{' => {
                    self.push_token(LBrace, &tokens);
                    self.next();
                },
                '}' => {
                    self.push_token(RBrace, &tokens);
                    self.next();
                },
                '[' => {
                    self.push_token(LBracket, &tokens);
                    self.next();
                },
                ']' => {
                    self.push_token(RBracket, &tokens);
                    self.next();
                },
                '\'' | '"' => self.string_literal(&tokens),
                '*' => {
                    const next_char = self.lookahead() orelse '\\';
                    if (next_char == '*') {
                        self.push_token(Power, &tokens);
                        self.next();
                    } else {
                        self.push_token(Multiply, &tokens);
                    }
                    self.next();
                },
                '/' => {
                    self.push_token(Divide, &tokens);
                    self.next();
                },
                '^' => {
                    self.push_token(Power, &tokens);
                    self.next();
                },
                '+' => {
                    self.push_token(Plus, &tokens);
                    self.next();
                },
                '?' => {
                    self.push_token(Help, &tokens);
                    self.next();
                },
                '<' => {
                    const next_char = self.lookahead() orelse '\\';
                    switch (next_char) {
                        '-' => {
                            self.push_token(LAssign, &tokens);
                            self.next();
                        },
                        '=' => {
                            self.push_token(LowerEqual, &tokens);
                            self.next();
                        },
                        '<' => {
                            self.push_token(SuperAssign, &tokens);
                            self.next();
                            self.next();
                        },
                        else => self.push_token(LowerThan, &tokens),
                    }
                    self.next();
                },
                '>' => {
                    const next_char = self.lookahead() orelse '\\';
                    if (next_char == '=') {
                        self.push_token(GreaterEqual, &tokens);
                        self.next();
                    } else {
                        self.push_token(GreaterThan, &tokens);
                    }
                    self.next();
                },
                '|' => {
                    const next_char = self.lookahead() orelse '\\';
                    if (next_char == '|') {
                        self.push_token(Or, &tokens);
                        self.next();
                    } else if (next_char == '>') {
                        self.push_token(Pipe, &tokens);
                        self.next();
                    } else {
                        self.push_token(VectorizedOr, &tokens);
                    }
                    self.next();
                },
                '&' => {
                    const next_char = self.lookahead() orelse '\\';
                    if (next_char == '&') {
                        self.push_token(And, &tokens);
                        self.next();
                    } else {
                        self.push_token(VectorizedAnd, &tokens);
                    }
                    self.next();
                },
                '=' => {
                    const next_char = self.lookahead() orelse '\\';
                    if (next_char == '=') {
                        self.push_token(Equal, &tokens);
                        self.next();
                    } else {
                        self.push_token(OldAssign, &tokens);
                    }
                    self.next();
                },
                '$' => {
                    self.push_token(Dollar, &tokens);
                    self.next();
                },
                '-' => {
                    const next_char = self.lookahead() orelse '\\';
                    if (next_char == '>') {
                        self.push_token(RAssign, &tokens);
                        self.next();
                    } else {
                        self.push_token(Minus, &tokens);
                    }
                    self.next();
                },
                '!' => {
                    self.next();
                    if (self.current_char == '=') {
                        self.push_token(NotEqual, &tokens);
                        self.next();
                    } else {
                        self.push_token(UnaryNot, &tokens);
                    }
                },
                '.' => {
                    const next_char = self.lookahead() orelse '\\';
                    if (next_char >= 'a' and next_char <= 'z' or next_char >= 'A' and next_char <= 'Z') {
                        self.identifier(&tokens);
                    } else if (next_char >= '0' and next_char <= '9') {
                        self.number_literal(&tokens);
                    } else {
                        self.identifier(&tokens);
                    }
                },
                '`' | '_' => self.identifier(&tokens),
                '%' => {
                    const next_char = self.lookahead() orelse '\\';
                    if (next_char == '%') {
                        self.push_token(Modulo, &tokens);
                        self.next();
                        self.next();
                    } else {
                        const custom_binary_start = self.it.it;
                        self.next();
                        while (self.current_char != '%') {
                            self.next();
                        }
                        const custom_binary_end = self.it.it;
                        self.push_token(Special(self.raw_source[custom_binary_start..custom_binary_end]), &tokens);
                        self.next();
                    }
                },
                'a'...'z', 'A'...'Z' => self.identifier_or_reserved(&tokens),
                '0'...'9' => self.number_literal(&tokens),
                '\\' => {
                    self.push_token(Lambda, &tokens);
                    self.next();
                },
                '#' => self.comment(&tokens),
                '~' => {
                    self.push_token(Tilde, &tokens);
                    self.next();
                },
                '@' => {
                    self.push_token(Slot, &tokens);
                    self.next();
                },
                ':' => {
                    self.next();
                    self.next(); // consume the ':'
                    const next_char_colon = self.lookahead();
                    if (self.current_char == ':' and next_char_colon == ':') {
                        self.push_token(NsGetInt, &tokens);
                        self.next();
                        self.next();
                    } else if (self.current_char == ':') {
                        self.push_token(NsGet, &tokens);
                        self.next();
                    } else if (self.current_char == '=') {
                        self.push_token(ColonAssign, &tokens);
                        self.next();
                    } else {
                        self.push_token(Colon, &tokens);
                    }
                },
                else => {},
            }
        }
        tokens.append(CommentedToken.new(EOF, self.offset));
        return tokens.toOwnedSlice();
    }

    fn push_token(self: *Tokenizer, token: Token, tokens: *[]CommentedToken) void {
        tokens.append(CommentedToken.new(token, self.offset));
    }

    pub fn next(self: *Tokenizer) ?CommentedToken {
        if (self.tokens.items.len == 0) {
            return null; // No more tokens
        }
        const token = self.tokens.items[0]; // Get the first token
        self.tokens.items = self.tokens.items[1..];
        return token;
    }
};
