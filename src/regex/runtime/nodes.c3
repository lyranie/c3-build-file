<*
    This module contains all the node types that regexen can have
*>
module regex::runtime::nodes;
<* What type of node is this node *>
enum NodeType : char
{
    WILDCARD,               // .
    CHARACTER,              // A single character, can be repeated any number of times
                            // The lowering step is what will do the eventual character to string conversion
    BACKREF,                // A backreference (\x)
    CONCAT,                 // 2 nodes followed by eachother
    DISJUNCT,               // |
    NEGATIVE_CG,            // [^...]
    POSITIVE_CG,            // [...]
    START_ANCHOR,           // ^
    END_ANCHOR,             // $
    WORD_ANCHOR,            // \w
    NOT_WORD_ANCHOR,        // \W
    AT_MOST,                // {,y} (this is actually to implement "BETWEEN" which is concat of exactly and at_most)
    ONE_OR_MORE,            // +
    ZERO_OR_MORE,           // *
    ZERO_OR_ONE,            // ?
    EXACTLY,                // {x}
    CAPTURE_GROUP,          // (...)
    POSITIVE_LOOKAHEAD,     // (?=...)
    NEGATIVE_LOOKAHED,      // (?:...)
}