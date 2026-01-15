<*
    This module implements the basic regex character class functions

    Currently these only work on ascii characters, though are modified to take UTF-8 input
*>
module regex::character_functions;

<*
    Checks if check is alphanumeric or underscore
*>
fn bool is_word(Char32 check)
{
    return (check >= '0' && check <= '9') ||
           (check >= 'a' && check <= 'z') ||
           (check >= 'A' && check <= 'Z') ||
           check == '_';
}

<*
    Checks if check is alphanumeric
*>
fn bool is_alnum(Char32 check)
{
    return (check >= '0' && check <= '9') ||
           (check >= 'a' && check <= 'z') ||
           (check >= 'A' && check <= 'Z');
}

<*
    Checks if a character is a space
*>
fn bool is_space(Char32 check)
{
    return check < 128 && ((char)check).is_space();
}

<*
    Checks if a character is a digit
*>
fn bool is_digit(Char32 check)
{
    return check >= '0' && check <= '9';
}

<*
    Checks if a character is a letter
*>
fn bool is_alpha(Char32 check)
{
    return (check >= 'a' && check <= 'z') ||
           (check >= 'A' && check <= 'Z');
}

<*
    Checks if a character is blank
*>
fn bool is_blank(Char32 check)
{
    return check < 128 && ((char)check).is_blank();
}

<*
    Checks if a character is a control character
*>
fn bool is_cntrl(Char32 check)
{
    return check < 128 && ((char)check).is_cntrl();
}

<*
    Checks if a character is a graph character
*>
fn bool is_graph(Char32 check)
{
    return check < 128 && ((char)check).is_graph();
}

<*
    Checks if a character is lowercase
*>
fn bool is_lower(Char32 check)
{
    return check >= 'a' && check <= 'z';
}

<*
    Checks if a character is uppercase
*>
fn bool is_upper(Char32 check)
{
    return check >= 'A' && check <= 'Z';
}

<*
    Checks if a character is printable
*>
fn bool is_print(Char32 check)
{
    return check < 128 && ((char)check).is_print();
}

<*
    Checks if a character is a hex digit
*>
fn bool is_xdigit(Char32 check)
{
    return (check >= '0' && check <= '9') ||
           (check >= 'a' && check <= 'f') ||
           (check >= 'A' && check <= 'F');
}

<*
    Checks if a character is punctuation
*>
fn bool is_punct(Char32 check)
{
    return check < 128 && ((char)check).is_punct();
}