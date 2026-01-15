<*
    This module implements the concept of character groups in a regular expression using a hashset for single characters, a list of functions for classes, and a list of ranges
*>
module regex::runtime::character_class;

import std::io;
import std::collections::set;
import std::collections::list;

<* This is used to apply is_digit() and other functions to the character class *>
alias CharacterFn = fn bool(Char32);

struct CharacterRange @private
{
    Char32 min;
    Char32 max;
}

/* TODO: Lessen memory usage here, as all 3 should be using the same allocator */
struct CharacterClass
{
    HashSet { Char32 } valid_characters;
    List { CharacterFn } functions;
    List { CharacterRange } ranges;
}

fn void CharacterClass.tinit(&self)
{
    self.valid_characters.tinit();
    self.functions.tinit();
    self.ranges.tinit();
}

<*
    @param [&inout] allocator : "The allocator to use"
*>
fn void CharacterClass.init(&self, Allocator allocator)
{
    self.valid_characters.init(allocator);
    self.functions.init(allocator);
    self.ranges.init(allocator);
}

fn void CharacterClass.free(&self)
{
    self.valid_characters.free();
    self.functions.free();
    self.ranges.free();
}

<*
    Add a character to this character set

    @param c : "The character to add to the set"
*>
fn void CharacterClass.add_character(&self, Char32 c)
{
    self.valid_characters.add(c);
}

<*
    Add a function to check to the character class

    @param funct : "The function to apply"
*>
fn void CharacterClass.add_fn(&self, CharacterFn funct)
{
    self.functions.push(funct);
}

<*
    Add a range to the character class

    @param min : "The beginning of the range, inclusive"
    @param max : "The end of the range, inclusive"
*>
fn void CharacterClass.add_range(&self, Char32 min, Char32 max)
{
    self.ranges.push({min, max});
}


<*
    Check if the character class has a given character

    @param value       : "The character to check for"
    @param ignore_case : "Should case be ignored when checking if the character is in the set, currently only checks case in ASCII"

    @return "If the character class has the given character"
*>
fn bool CharacterClass.has(&self, Char32 value, bool ignore_case = false) 
{
    if (!ignore_case || !((value >= 'a' && value <= 'z') || (value >= 'A' && value <= 'Z')))
    {
        if (self.valid_characters.contains(value)) return true;

        foreach (funct : self.functions)
        {
            if (funct(value)) return true;
        }

        foreach (range : self.ranges)
        {
            if (value >= range.min && value <= range.max) return true;
        }

        return false;
    }
    else
    {
        return self.has(((char)value).to_lower()) || self.has(((char)value).to_upper());
    }
}

<*
    Copy a character class using an allocator

    @param allocator : "The allocator to copy with"

    @return "A copy of the character class"
*>
fn CharacterClass CharacterClass.copy(&self, Allocator allocator)
{
    CharacterClass result;
    if (self.valid_characters.len() != 0) result.valid_characters.init_from_set(allocator, &self.valid_characters);
    result.functions.init_with_array(allocator, self.functions.array_view());
    result.ranges.init_with_array(allocator, self.ranges.array_view());
    return result;
}

<*
    Check if a character class equals another

    @param other : "The character class to check against"
*>
fn bool CharacterClass.equals(&self, CharacterClass other) @operator(==)
{
    if (self.valid_characters.len() != other.valid_characters.len()) return false;
    if (self.functions.len() != other.functions.len()) return false;
    if (self.ranges.len() != other.ranges.len()) return false;
    self.valid_characters.@each(; Char32 value)
    {
        if (!other.valid_characters.contains(value)) return false;
    };

    foreach (function : self.functions)
    {
        bool found = false;
        foreach (function2 : other.functions)
        {
            if (function == function2)
            {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }

    foreach (range : self.ranges)
    {
        bool found = false;
        foreach (range2 : other.ranges)
        {
            if (range.min == range2.min && range.max == range2.max)
            {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }

    return true;
}