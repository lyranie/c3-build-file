<*
    This module contains information about tokens common to both implementations
*>
module regex::runtime::tokens;

<* The escape sequence used by the regex engine, it is `\` because `\` can be easily written in a raw literal*>
const ESCAPE_SEQUENCE = `\`;

enum RegexTokenType : char (TokenizerMode next_state_regular, TokenizerMode next_state_cg, TokenizerMode next_state_rq) 
{
    CHARACTER = {DEFLT,IN_CG,IN_RQ},           // Any sequence of characters
    POS_CG_BEGIN = {IN_CG,IN_CG,IN_RQ},       // [
    NEG_CG_BEGIN = {IN_CG,IN_CG,IN_RQ},       // [^
    CG_END = {DEFLT,DEFLT,DEFLT},             // ]
    WILDCARD = {DEFLT,IN_CG,IN_RQ},           // .
    DASH = {DEFLT,IN_CG,IN_RQ},               // - in character group
    WORD = {DEFLT,IN_CG,IN_RQ},               // \w
    NON_WORD = {DEFLT,IN_CG,IN_RQ},           // \W
    WHITESPACE = {DEFLT,IN_CG,IN_RQ},         // \s
    NON_WHITESPACE = {DEFLT,IN_CG,IN_RQ},     // \S
    DIGIT = {DEFLT,IN_CG,IN_RQ},              // \d
    NON_DIGIT = {DEFLT,IN_CG,IN_RQ},          // \D
    BACKREFERENCE = {DEFLT,IN_CG,IN_RQ},      // \int where n > 0
    GROUP_OPEN = {DEFLT,IN_CG,IN_RQ},         // (
    NO_BR_GROUP_OPEN = {DEFLT,IN_CG,IN_RQ},   // (?:
    GROUP_END = {DEFLT,IN_CG,IN_RQ},          // )
    ZERO_OR_MORE = {DEFLT,IN_CG,IN_RQ},       // *
    ONE_OR_MORE = {DEFLT,IN_CG,IN_RQ},        // +
    ZERO_OR_ONE = {DEFLT,IN_CG,IN_RQ},        // ?
    RQ_BEGIN = {IN_RQ,IN_CG,IN_RQ},           // {
    RQ_END = {DEFLT,IN_CG,DEFLT},             // }
    RQ_NUMBER = {DEFLT,IN_CG,IN_RQ},          // int
    RQ_SEPARATOR = {DEFLT,IN_CG,IN_RQ},       // ,
    BEGINNING = {DEFLT,IN_CG,IN_RQ},          // ^
    END = {DEFLT,IN_CG,IN_RQ},                // $
    WORD_BOUNDARY = {DEFLT,IN_CG,IN_RQ},      // \b
    NOT_WORD_BOUNDARY = {DEFLT,IN_CG,IN_RQ},  // \B
    POS_LOOK = {DEFLT,IN_CG,IN_RQ},           // (?=
    NEG_LOOK = {DEFLT,IN_CG,IN_RQ},           // (?!
    SEPARATOR = {DEFLT,IN_CG,IN_RQ},          // |
    ALNUM_CLASS = {DEFLT,IN_CG,IN_RQ},        // :alnum:,   :w:
    ALPHA_CLASS = {DEFLT,IN_CG,IN_RQ},        // :alpha:,   :a:
    BLANK_CLASS = {DEFLT,IN_CG,IN_RQ},        // :blank:,   :b:
    CNTRL_CLASS = {DEFLT,IN_CG,IN_RQ},        // :cntrl:,   :c:
    DIGIT_CLASS = {DEFLT,IN_CG,IN_RQ},        // :digit:,   :d:
    GRAPH_CLASS = {DEFLT,IN_CG,IN_RQ},        // :graph:,   :g:
    LOWER_CLASS = {DEFLT,IN_CG,IN_RQ},        // :lower:,   :l:
    PRINT_CLASS = {DEFLT,IN_CG,IN_RQ},        // :print:,   :p:
    SPACE_CLASS = {DEFLT,IN_CG,IN_RQ},        // :space:,   :s:
    UPPER_CLASS = {DEFLT,IN_CG,IN_RQ},        // :upper:,   :u:
    XDIGT_CLASS = {DEFLT,IN_CG,IN_RQ},        // :xdigit:,  :x:
    PUNCT_CLASS = {DEFLT,IN_CG,IN_RQ},        // :punct:,   :.:
}

struct RegexToken 
{
    RegexTokenType type;
    union context 
    {
        uint num;
        Char32 ch;
    }
}

enum TokenizerMode
{
    DEFLT,
    IN_CG,
    IN_RQ
}

struct TokenMapEntry
{
    String prefix;
    RegexTokenType type;
}

const TokenMapEntry[*] TOP_LEVEL_TOKEN_MAP = {
    {"[^", NEG_CG_BEGIN},
    {"[", POS_CG_BEGIN},
    {"]", CG_END},
    {".", WILDCARD},
    {ESCAPE_SEQUENCE +++ "w", WORD},
    {ESCAPE_SEQUENCE +++ "W", NON_WORD},
    {ESCAPE_SEQUENCE +++ "s", WHITESPACE},
    {ESCAPE_SEQUENCE +++ "S", NON_WHITESPACE},
    {ESCAPE_SEQUENCE +++ "d", DIGIT},
    {ESCAPE_SEQUENCE +++ "D", NON_DIGIT},
    {"(?:", NO_BR_GROUP_OPEN},
    {"(?=", POS_LOOK},
    {"(?!", NEG_LOOK},
    {"(", GROUP_OPEN},
    {")", GROUP_END},
    {"*", ZERO_OR_MORE},
    {"+", ONE_OR_MORE},
    {"?", ZERO_OR_ONE},
    {"{", RQ_BEGIN},
    {"}", RQ_END},
    {"^", BEGINNING},
    {"$", END},
    {ESCAPE_SEQUENCE +++ "b", WORD_BOUNDARY},
    {ESCAPE_SEQUENCE +++ "B", NOT_WORD_BOUNDARY},
    {"|", SEPARATOR}
};

const TokenMapEntry[*] CG_TOKEN_MAP = {
    {"[:alpha:]", ALPHA_CLASS}, {"[:a:]", ALPHA_CLASS},
    {"[:alnum:]", ALNUM_CLASS}, {"[:w:]", ALNUM_CLASS},
    {"[:blank:]", BLANK_CLASS}, {"[:b:]", BLANK_CLASS},
    {"[:cntrl:]", CNTRL_CLASS}, {"[:c:]", CNTRL_CLASS},
    {"[:digit:]", DIGIT_CLASS}, {"[:d:]", DIGIT_CLASS},
    {"[:graph:]", GRAPH_CLASS}, {"[:g:]", GRAPH_CLASS},
    {"[:lower:]", LOWER_CLASS}, {"[:l:]", LOWER_CLASS},
    {"[:print:]", PRINT_CLASS}, {"[:p:]", PRINT_CLASS},
    {"[:space:]", SPACE_CLASS}, {"[:s:]", SPACE_CLASS},
    {"[:upper:]", UPPER_CLASS}, {"[:u:]", UPPER_CLASS},
    {"[:xdigit:]",XDIGT_CLASS}, {"[:x:]", XDIGT_CLASS},
    {"[:punct:]", PUNCT_CLASS}, {"[:.:]", PUNCT_CLASS},
    {"]", CG_END},
    {"-", DASH},
    {"[", POS_CG_BEGIN},
};