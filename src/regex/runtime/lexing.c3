<*
    This module lexes a regex
*>
module regex::runtime::lexing;

import std::collections::list;
import regex;
import regex::utf8;
import regex::runtime::tokens;

struct TokenizerContext 
{
    String tokenizing;
    TokenizerMode mode;

    bool has_stored_backtrack;
    RegexToken stored_back_track;

    Options options;
}

fn TokenizerContext on(String regex, Options options) 
{
    return {
        regex,
        DEFLT,
        false,
        {},
        options
    };
}


<*
    Construct a unicode character from ascii hex digits (Parameters are in an odd order to make it reusable)

    @param hi : "The most significant nibble"
    @param low : "The least significant nibble"
*>
fn Char32 from_hex(char hi, char low) @private {
    return ((Char32)ascii::HEX_VALUE[hi] << 4) |
           (Char32)ascii::HEX_VALUE[low];
}

macro Char32 from_hex_unicode(char x) @private => (Char32)ascii::HEX_VALUE[x];

<*
    @param after_escape      : "The part after the escape sequence being handled"
    @param [&out] consumed   : "How much of the string after the slash is consumed"

    @return? regex::INVALID_ESCAPE_SEQUENCE : "If the escape sequence is invalid"
*>
fn Char32? handle_escape_character(String after_escape, usz* consumed) @private
{
    if (after_escape.len == 0) return regex::INVALID_ESCAPE_SEQUENCE?;

    *consumed = 1;
    
    switch (after_escape[0])
    {
        case 't':
            return '\t';
        case 'n':
            return '\n';
        case 'v':
            return '\v';
        case 'f':
            return '\f';
        case 'r':
            return '\r';
        case 'c':
            if (after_escape.len == 1) return regex::INVALID_ESCAPE_SEQUENCE?;
            *consumed = 2;
            return after_escape[1] & 31;
        case 'x':
            *consumed = 3;
            if (after_escape.len < 3) return regex::INVALID_ESCAPE_SEQUENCE?;
            if (!after_escape[1].is_xdigit() || !after_escape[2].is_xdigit()) return regex::INVALID_ESCAPE_SEQUENCE?;
            return from_hex(after_escape[1], after_escape[2]);
        case 'u':
            usz actually_consumed = 1;
            if (after_escape.len < 2) return regex::INVALID_ESCAPE_SEQUENCE?;
            if (!after_escape[1].is_xdigit()) return regex::INVALID_ESCAPE_SEQUENCE?;
            Char32 result = 0;
            do {
                result <<= 4;
                result |= from_hex_unicode(after_escape[actually_consumed]);
                actually_consumed += 1;
            } while (actually_consumed < 7 && actually_consumed < after_escape.len && after_escape[actually_consumed].is_xdigit());
            *consumed = actually_consumed;
            if (result > 0x10FFFF) return regex::INVALID_ESCAPE_SEQUENCE?;
            return result;
        case '0':
            return 0;
        default:
            return after_escape[0];
    }
}


<*
    @return "Is the tokenizer done tokenizing"
    @pure
*>
fn bool TokenizerContext.done(&self) @inline => !self.has_stored_backtrack && self.mode == DEFLT && self.tokenizing.len == 0;

<*
    @return? regex::UNTERMINATED_CHARACTER_GROUP : "[ was not matched with ]"
    @return? regex::UNTERMINATED_RANGE_QUANTIFIER : "{ was not matched with }"
    @return? regex::UNEXPECTED_CHARACTER : "There was an unexpected character in the sequence"
    @return? regex::INVALID_ESCAPE_SEQUENCE : "The regex had an invalid escape sequence"
    @return? regex::UNEXPECTED_END_OF_INPUT : "The tokenizer is being requested to get more tokens than are in the input"
    @return? regex::INVALID_CAPTURE_GROUP_ID : "If the regex has a back reference to a capture group of index 65536 or greater"
*>
fn RegexToken? TokenizerContext.get_next_token(&self) 
{
    if (self.has_stored_backtrack)
    {
        self.has_stored_backtrack = false;

        return self.stored_back_track;
    }

    if (self.tokenizing.len == 0)
    {
        switch (self.mode) 
        {
            case IN_CG:
                self.mode = DEFLT;
                return regex::UNTERMINATED_CHARACTER_GROUP?;
            case IN_RQ:
                self.mode = DEFLT;
                return regex::UNTERMINATED_RANGE_QUANTIFIER?;
            default:
                return regex::UNEXPECTED_END_OF_INPUT?;
        }
    }
    usz consumed = 0;
    RegexToken result;
    switch (self.mode) 
    {
        case DEFLT:
            result = self.deflt(&consumed)!;
            self.mode = result.type.next_state_regular;
        case IN_RQ:
            result = self.rq(&consumed)!;
            self.mode = result.type.next_state_rq;
        case IN_CG:
            result = self.cg(&consumed)!;
            self.mode = result.type.next_state_cg;
    }
    self.tokenizing = self.tokenizing[consumed..];
    return result;
}



<*
    @param [&inout] consumed : "How much data was consumed"

    @return "The next regex token in the default mode"
*>
fn RegexToken? TokenizerContext.deflt(&self, usz* consumed) @private
{
    String regex = self.tokenizing;

    foreach (entry : tokens::TOP_LEVEL_TOKEN_MAP) 
    {
        if (regex.starts_with(entry.prefix)) 
        {
            *consumed = entry.prefix.len;
            RegexToken result;
            result.type = entry.type;
            return result;
        }
    }

    if (regex.starts_with(tokens::ESCAPE_SEQUENCE)) 
    {
        if (regex.len == tokens::ESCAPE_SEQUENCE.len) return regex::INVALID_ESCAPE_SEQUENCE?;
        if (regex[tokens::ESCAPE_SEQUENCE.len].is_digit() && regex[tokens::ESCAPE_SEQUENCE.len] != '0')
        {
            usz end_index = tokens::ESCAPE_SEQUENCE.len + 1;
            for (usz i = end_index; i < regex.len && regex[i].is_digit(); i++) 
            {
                end_index = i;
            }
            *consumed = end_index;
            RegexToken result;
            result.type = BACKREFERENCE;
            result.context.num = regex[1..end_index - 1].to_integer(uint)!;
            if (result.context.num > 65535) return regex::INVALID_CAPTURE_GROUP_ID?;
            return result;
        } 
        else 
        {
            RegexToken result;
            result.type = CHARACTER;
            result.context.ch = handle_escape_character(regex[1..], consumed)!;
            *consumed += tokens::ESCAPE_SEQUENCE.len;
            return result;
        }
    }

    RegexToken result;
    result.type = CHARACTER;
    // Let's use a unicode character here
    if (self.options & Options.ASCII_ONLY == 0)
    {
        result.context.ch = utf8::get_character(regex, consumed)!;
    }
    else
    {
        *consumed = 1;
        result.context.ch = regex[0];
    }
    return result;
}

<*
    @param [&inout] consumed : "How much data was consumed"

    @return "The next regex token in the range qualifier mode"
*>
fn RegexToken? TokenizerContext.rq(&self, usz* consumed) @private
{
    String regex = self.tokenizing;

    if (regex[0] == '}') 
    {
        RegexToken result;
        result.type = RQ_END;
        *consumed = 1;
        return result;
    }
    else if (regex[0] == ',') 
    {
        RegexToken result;
        result.type = RQ_SEPARATOR;
        *consumed = 1;
        return result;
    }

    if (!regex[0].is_digit()) 
    {
        return regex::UNEXPECTED_CHARACTER?;
    }

    while (*consumed < regex.len && regex[*consumed].is_digit()) 
    {
        *consumed += 1;
    }

    RegexToken result;
    result.type = RQ_NUMBER;
    result.context.num = regex[..*consumed - 1].to_integer(uint)!;
    return result;
}

<*
    @param [&inout] consumed : "How much data was consumed"

    @return "The next regex token in the character group mode"
*>
fn RegexToken? TokenizerContext.cg(&self, usz* consumed) @private
{
    String regex = self.tokenizing;

    foreach (entry : tokens::CG_TOKEN_MAP) 
    {
        if (regex.starts_with(entry.prefix))
        {
            *consumed = entry.prefix.len;
            RegexToken result;
            result.type = entry.type;
            return result;
        }
    }

    if (!regex.starts_with(tokens::ESCAPE_SEQUENCE)) {
        RegexToken result;
        result.type = CHARACTER;
        if (self.options & Options.ASCII_ONLY == 0)
        {
            result.context.ch = utf8::get_character(regex, consumed)!;
        }
        else
        {
            *consumed = 1;
            result.context.ch = regex[0];
        }
        return result;
    }

    RegexToken result;
    result.type = CHARACTER;
    result.context.ch = handle_escape_character(regex[tokens::ESCAPE_SEQUENCE.len..],consumed)!;
    *consumed += tokens::ESCAPE_SEQUENCE.len;

    return result;
}

<*
    Backtrack one regex token

    @require !self.has_stored_backtrack : "This tokenizer can only backtrack one token"
*>
fn void TokenizerContext.backtrack(&self, RegexToken token)
{
    self.has_stored_backtrack = true;
    self.stored_back_track = token;
}