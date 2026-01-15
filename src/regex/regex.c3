module regex;
import regex::runtime::automata;
import regex::runtime::lowering;
import std::io;

alias RuntimeRegex = automata::NfaRegex;

faultdef NO_MATCH;
faultdef INVALID_ESCAPE_SEQUENCE;
faultdef UNTERMINATED_CHARACTER_GROUP;
faultdef UNTERMINATED_RANGE_QUANTIFIER;
faultdef UNEXPECTED_CHARACTER;
faultdef UNFILLED_RANGE_QUANTIFIER;
faultdef UNEXPECTED_END_OF_INPUT;
faultdef INVALID_RANGE_QUANTIFIER;
faultdef UNEXPECTED_TOKEN;
faultdef UNTERMINATED_SUBEXPRESSION;
faultdef INVALID_CAPTURE_GROUP_ID;
faultdef EXTRANEOUS_PARENTHESES;

<*
    This error means that the resulting regex has more than 2^24 states or a single state has more than 2^24 edges

    If this is the case then the regex engine will break if it tries to run the regex, so it returns a fault
*>
faultdef REGEX_TOO_COMPLEX;


<*
    Options that change how regexes behave
*>
enum Options : const char 
{
    <* Default regex behaviour *>
    NONE = 0,
    <* $ and ^ match on lines instead of the full string *>
    MULTILINE = 1,
    <* . consumes any amount characters *>
    SINGLE_LINE = 2,
    <* Ignore case when matching *>
    IGNORE_CASE = 4,
    <* Do all comparisons and parsing in ASCII (i.e. characters are solely 1 byte) *>
    ASCII_ONLY = 8,

    <* Do not epsilon reduce the automata *>
    NO_REDUCTION = 0x80
}

<*
    An interface for a regex implementation, done such that making other backends can be much easier in the future
*>
interface Regex 
{
    <*
        @param view             : "The string view being matched over"
        @param offset           : "The offset in the view to match at"
        @param match_allocator   : "The allocator being used to allocate the array of captures"

        @return? NO_MATCH : "If there is no match starting at the offset"
        @return "A match starting at the offset"
    *>
    fn Match? match_in_view(String view, usz offset, Allocator match_allocator);

    <*
        @param view : "The string to match"
        
        @return "If the entire string matches the regex"
    *>
    fn bool matches(String view);

    <*
        Releases the memory used to describe the regex, may be empty on a compile time implementation
    *>
    fn void free();
}

struct Match (Printable)
{
    Allocator allocator;
    String full_view;
    <* capture_begin is inclusive*>
    usz *capture_begin;
    <* capture_end is exclusive*>
    usz *capture_end;
    ushort num_captures;
}


fn void Match.free(&self) 
{
    allocator::free(self.allocator,self.capture_begin);
    allocator::free(self.allocator,self.capture_end);
}

fn usz Match.begin_offset(&self) => self.capture_begin[0];
fn usz Match.end_offset(&self) => self.capture_end[0];
fn String Match.matched(&self) => self.full_view[self.begin_offset() .. self.end_offset() - 1];

fn usz? Match.to_format(&self, Formatter* formatter) @dynamic
{
    return formatter.printf("Match @ [%d, %d): %s", self.begin_offset(), self.end_offset(), self.matched());
}

<*
    @require i < self.num_captures : "Capture is out of bounds"
*>
fn Capture Match.get(&self, usz i) @operator([]) 
{
    if (self.capture_begin[i] == usz.max || self.capture_end[i] == usz.max)
    {
        return {
            "",
            self.capture_begin[i],
            self.capture_end[i]
        };
    }
    else
    {
        return {
            self.full_view[self.capture_begin[i]..self.capture_end[i] - 1],
            self.capture_begin[i],
            self.capture_end[i]
        };
    }
}

fn usz Match.len(&self) @operator(len) 
{
    return self.num_captures;
}

struct Capture (Printable) 
{
    String captured;
    usz begin;
    usz end;
}

fn bool Capture.valid(&self)
{
    return self.begin != usz.max && self.end != usz.max;
}

fn usz? Capture.to_format(&self, Formatter* formatter) @dynamic
{
    if (self.valid())
    {
        return formatter.printf("Capture @ [%d, %d): %s", self.begin, self.end, self.captured);
    }
    else
    {
        return formatter.printf("<invalid capture>");
    }
}


fn RuntimeRegex? make_runtime_regex(String regex, Options options, Allocator allocator) @inline => lowering::compile_regex(regex, options, allocator);

<* 
    This is an iterator over regex matches
*>
struct MatchIterator {
    <* The regex being applied *>
    Regex regex;
    <* The index of the iterator *>
    usz idx;
    <* The string being checked *>
    String view;
}

fn MatchIterator Regex.iter_matches(self, String view)
{
    return {
        self,
        0,
        view
    };
}

faultdef NO_MORE_MATCHES;

fn Match? MatchIterator.next(&self, Allocator match_allocator=tmem) {
    while (self.idx < self.view.len) {
        if (try match = self.regex.match_in_view(self.view,self.idx,match_allocator)) {
            if (match.end_offset() - match.begin_offset() == 0) {
                self.idx += 1;
            }
            else {
                self.idx = match.end_offset();
            }
            return match;
        } else {
            self.idx += 1;
        }
    }
    return NO_MORE_MATCHES?;
}