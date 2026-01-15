<*
    This module contains common information about states common to both implementations
*>
module regex::runtime::states;

<*
    The action of an edge in a state
*>
enum TransitionType : char
{
    <* Empty transition *>
    EPSILON,

    <* Transition on non-newline (any character if SINGLE_LINE is set), can be repeated *>
    WILDCARD,
    <* Transition on a specific string *>
    STRING,
    <* Transition on character being in character group, can be repeated *>
    POS_CHARACTER,
    <* Transition on character not being in character group, can be repeated *>
    NEG_CHARACTER,
    <* Transition on the following sequence being the same as the referant capture group, can be repeated*>
    BACK_REFERENCE,

    <* Transition if given child automaton matches from the current position *>
    POS_LOOKAHEAD,
    <* Transition if given child automaton does not match from the current position *>
    NEG_LOOKAHEAD,
    <* Transition if at start of string, or start of line if MULTILINE is set *>
    START,
    <* Transition if at end of string, or end of line if SINGLE_LINE is set *>
    END,
    <* Transition if at a word boundary *>
    WORD_BOUNDARY,
    <* Transition if not at a word boundary *>
    NOT_WORD_BOUNDARY
}
