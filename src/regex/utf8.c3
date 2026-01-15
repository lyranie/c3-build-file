<*
    This module contains utility methods for dealing with utf8 in regexen
*>
module regex::utf8;
faultdef INVALID_UTF8_SEQUENCE;

/*
    Constants relating to how utf8 is encoded
*/
const TWO_BYTE_MASK = 0b1110_0000;
const TWO_BYTE_SEQUENCE = 0b1100_0000;
const THREE_BYTE_MASK = 0b1111_0000;
const THREE_BYTE_SEQUENCE = 0b1110_0000;
const FOUR_BYTE_MASK = 0b1111_1000;
const FOUR_BYTE_SEQUENCE = 0b1111_0000;
const TRAILING_MASK = 0b1100_0000;
const TRAILING_SEQUENCE = 0b1000_0000;

<*
    Get a utf8 character from the front of a string

    @param view            : "The string we are finding a utf8 character at the start of"
    @param [&out] consumed : "How many bytes long was the utf8 sequence"

    @return? INVALID_UTF8_SEQUENCE : "The front of the string is an invalid utf8 sequence"
    @return "A Char32 representing a unicode codepoint from the utf8 sequence"
*>
fn Char32? get_character(String view, usz* consumed)
{
    if (view.len == 0) return INVALID_UTF8_SEQUENCE?;

    Char32 first_byte = view[0];
    if (first_byte < 128)
    {
        *consumed = 1;
        return first_byte;
    }

    if (view.len < 2) return INVALID_UTF8_SEQUENCE?;
    Char32 second_byte = view[1];
    if (second_byte & TRAILING_MASK != TRAILING_SEQUENCE) return INVALID_UTF8_SEQUENCE?;

    if (first_byte & TWO_BYTE_MASK == TWO_BYTE_SEQUENCE)
    {
        // 2 byte sequence
        *consumed = 2;
        return ((first_byte & ~TWO_BYTE_SEQUENCE) << 6) | (second_byte & ~TRAILING_SEQUENCE);
    }
    else if (first_byte & THREE_BYTE_MASK == THREE_BYTE_SEQUENCE)
    {
        // 3 byte sequence
        if (view.len < 3) return INVALID_UTF8_SEQUENCE?;
        *consumed = 3;
        Char32 third_byte = view[2];
        if (third_byte & TRAILING_MASK != TRAILING_SEQUENCE) return INVALID_UTF8_SEQUENCE?;
        return ((first_byte & ~THREE_BYTE_SEQUENCE) << 12) | 
               ((second_byte & ~TRAILING_SEQUENCE) << 6)| 
               (third_byte & ~TRAILING_SEQUENCE);
    }
    else if (first_byte & FOUR_BYTE_MASK == FOUR_BYTE_SEQUENCE)
    {
        // 4 byte sequence
        if (view.len < 4) return INVALID_UTF8_SEQUENCE?;
        *consumed = 4;
        Char32 third_byte = view[2];
        if (third_byte & TRAILING_MASK != TRAILING_SEQUENCE) return INVALID_UTF8_SEQUENCE?;
        Char32 fourth_byte = view[3];
        if (fourth_byte & TRAILING_MASK != TRAILING_SEQUENCE) return INVALID_UTF8_SEQUENCE?;
        return ((first_byte & ~FOUR_BYTE_SEQUENCE) << 18) | 
               ((second_byte & ~TRAILING_SEQUENCE) << 12) | 
               ((third_byte & ~TRAILING_SEQUENCE) << 6) | 
               (fourth_byte & ~TRAILING_SEQUENCE);
    }
    else
    {
        return INVALID_UTF8_SEQUENCE?;
    }
}

<*
    Get how many bytes a utf8 character will take up

    @param ch : "The character to check"

    @return "How many bytes the character will take when encoded into it's minimal form"
*>
fn usz get_len(Char32 ch)
{
    if (ch <= 0x7F)
    {
        return 1;
    }
    if (ch <= 0x7FFF)
    {
        return 2;
    }
    if (ch <= 0xFFFF)
    {
        return 3;
    }
    return 4;
}

<*
    Check if a string starts with an utf8 string

    @param view            : "The string to be checking"
    @param prefix          : "The prefix to check"
    @param [&out] consumed : "The amount of length in the view the prefix took"
    @param case_sensitive  : "Is this check case sensitive?"

    @return "If view starts with prefix"
*>
fn bool starts_with(String view, String prefix, usz* consumed, bool case_sensitive)
{
    usz i_view;
    usz i_prefix;
    defer *consumed = i_view;

    while (i_prefix < prefix.len)
    {
        if (i_view >= view.len) return false;
        usz consumed_view;
        usz consumed_prefix;

        if (try v = get_character(view[i_view..], &consumed_view))
        {
            if (try p = get_character(prefix[i_prefix..], &consumed_prefix))
            {
                
                // if (v != p) return false;
                if (v != p)
                {
                    if (case_sensitive) return false;
                    if (v > 128 || p > 128) return false;
                    if (ascii::to_lower((char)v) != ascii::to_lower((char)p)) return false;
                }
                i_view += consumed_view;
                i_prefix += consumed_prefix;
            }
            else
            {
                return false;
            }
        }
        else
        {
            return false;
        }
    }

    return true;
}