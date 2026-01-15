<*
    This module contains a runtime non-deterministic finite automata engine for running regular expressions
*>
module regex::runtime::automata;

import regex;
import regex::utf8;
import regex::runtime::stack_context;
import regex::runtime::states;
import std::collections::list;

union EdgeData 
{
    <* for WILDCARD *>
    struct wildcard 
    {
        uint repeat_count;
    }

    <* For STRING *>
    struct string 
    {
        uint begin;
        uint len;
    }

    <* For POS_CHARACTER and NEG_CHARACTER *>
    struct character 
    {
        uint index;
        uint repeat_count;
    }

    <* For BACK_REFERENCE *>
    struct back_reference 
    {
        ushort capture_group_index;
        uint repeat_count;
    }

    <* For POS_LOOKAHEAD and NEG_LOOKAHEAD *>
    ushort sub_automaton_index;
}

<*
    Regex implementation composed of a set of NFAs 
*>
struct NfaRegex (Regex)
{
    Allocator allocator;
    
    <* How many automata are in this regex *>
    ushort automaton_count;
    <* The begin state number of the Nth automaton *>
    uint* automaton_begin;
    <* The end state number of the Nth automaton *>
    uint* automaton_end;

    <* How many states exist across all automata within this regex *>
    uint state_count;
    <* The offset into the edges table that this states edges begin at *>
    usz* state_edges_begin;
    <* The amount of edges this state has *>
    ushort* state_edge_count;

    <* How many edges exist in this regex *>
    usz edge_count;
    <* Where does the edge transition to *>
    uint* edge_to;
    <* What type of transition does this edge make *>
    TransitionType* transition_type;
    <* What capture group does this edge begin (0 if none) *>
    ushort* edge_capture_begin;
    <* What capture group does this edge end (0 if none) *>
    ushort* edge_capture_end;

    <* Data associated with this edge depending on the transition type *>
    EdgeData* edge_associated_data;

    <* Character classes for matching character groups*>
    CharacterClass[] character_class;

    <* All string matches concatenated together in one array *>
    String strings;

    <* How many capture groups there are *>
    ushort num_capture_groups;

    <* How is this regex configured *>
    Options options;
}


<*
    Determine the (minimum) consumption length for an edge

    @param [&in] self
    @param edge_offset   : "The index of the edge in the relevant tables"
    @param captures     : "The current capture group array"

    @require edge_offset < self.edge_count: "Edge is out of bounds"

    @return "How many characters are consumed by the given edge"
*>
fn usz NfaRegex.get_min_consumption_length(&self, usz edge_offset, CaptureEntry captures) @private 
{
    EdgeData data = self.edge_associated_data[edge_offset];
    switch (self.transition_type[edge_offset]) 
    {
        case WILDCARD:
            return data.wildcard.repeat_count;
        case STRING:
            return data.string.len;
        case POS_CHARACTER:
            return data.character.repeat_count;
        case NEG_CHARACTER:
            return data.character.repeat_count;
        case BACK_REFERENCE:
            return (captures.end[data.back_reference.capture_group_index - 1] - captures.begin[data.back_reference.capture_group_index - 1]) * data.back_reference.repeat_count;
        case EPSILON:
        case POS_LOOKAHEAD:
        case NEG_LOOKAHEAD:
        case START:
        case END:
        case WORD_BOUNDARY:
        case NOT_WORD_BOUNDARY:
            return 0;
    }
}

<*
    @param c : "The character being checked"

    @return "True if the character is alphanumeric or an underscore"
*>
fn bool is_word_character(char c) @private 
{
    return c.is_alnum() || c == '_';
}


<*
    Determines if a string starts with another in a case insensitive manner

    @param view   : "The string to be checking"
    @param prefix : "The prefix to check for"

    @return "If view starts with prefix"
*>
fn bool case_insensitive_starts_with(String view, String prefix) @private
{
    foreach (i, ch : prefix)
    {
        if (i >= view.len) return false;
        if (view[i].to_lower() != ch.to_lower()) return false;
    }
    return true;
}

<*
    Determine if the automaton should transition at this edge

    @param [&in] self
    @param edge_offset              : "The index of the edge in the relevant tables"
    @param current_index            : "The current index into the view"
    @param view                     : "The string being matched upon"
    @param captures                 : "The current capture array"
    @param [&out] actually_consumed : "The actual amount consumed (needed due to utf8)"

    @require edge_offset < self.edge_count: "Edge is out of bounds"
*>
fn bool NfaRegex.should_transition(&self, usz edge_offset, usz current_index, String view, CaptureEntry captures, usz* actually_consumed) @private 
{
    // Default is zero
    *actually_consumed = 0;
    EdgeData data = self.edge_associated_data[edge_offset];
    bool ascii_only = self.options & Options.ASCII_ONLY != 0;
    bool single_line = self.options & Options.SINGLE_LINE != 0;
    bool multiline = self.options & Options.MULTILINE != 0;
    bool case_sensitive = self.options & Options.IGNORE_CASE == 0;
    switch (self.transition_type[edge_offset]) 
    {
        case EPSILON:
            return true;
        case WILDCARD:
            if (ascii_only)
            {
                *actually_consumed = data.wildcard.repeat_count;
                if (single_line) 
                {
                    return true;
                }
                for (usz i = current_index; i < current_index + data.wildcard.repeat_count; i++) 
                {
                    if (i >= view.len) return false;
                    if (view[i] == '\n') return false;
                }
                return true;
            }
            else
            {
                usz consumed = 0;
                defer *actually_consumed = consumed;
                for (usz i = 0; i < data.wildcard.repeat_count; i++)
                {
                    if (current_index + consumed >= view.len) return false;
                    usz single_consumed;
                    if (try result = utf8::get_character(view[current_index + consumed..], &single_consumed))
                    {
                        if (!single_line && result == '\n')
                        {
                            return false;
                        }
                        consumed += single_consumed;
                    }
                    else
                    {
                        return false;
                    }
                }
                return true;
            }
        case STRING:
            if (ascii_only)
            {
                *actually_consumed = data.string.len;
                return case_sensitive
                        ? view[current_index..].starts_with(self.strings[data.string.begin:data.string.len])
                        : case_insensitive_starts_with(view[current_index..], self.strings[data.string.begin:data.string.len])
                        ;
            }
            else
            {
                return utf8::starts_with(view[current_index..],self.strings[data.string.begin:data.string.len],actually_consumed, case_sensitive);
            }
        case BACK_REFERENCE:
            usz begin = captures.begin[data.back_reference.capture_group_index - 1];
            usz end = captures.end[data.back_reference.capture_group_index - 1];
            if (begin == end) return true;
            if (begin > end) return false;
            if (begin >= view.len) return false;
            if (end > view.len) return false;
            String to_check = view[begin..end-1];
            if (ascii_only)
            {
                for (usz i = 0; i < data.back_reference.repeat_count; i++)
                {
                    if (case_sensitive)
                    {
                        if (!view[current_index + (to_check.len * i)..].starts_with(to_check)) return false;
                    }
                    else
                    {
                        if (!case_insensitive_starts_with(view[current_index + (to_check.len * i)..],to_check)) return false;
                    }
                }
                *actually_consumed = to_check.len * data.back_reference.repeat_count;
            }
            else
            {
                usz consumed = 0;
                defer *actually_consumed = consumed;
                for (usz i = 0; i < data.back_reference.repeat_count; i++)
                {
                    if (current_index + consumed >= view.len) return false;
                    usz single_consumed;
                    if (!utf8::starts_with(view[current_index + consumed..],to_check, &single_consumed, case_sensitive)) return false;
                    consumed += single_consumed;
                }
            }
            return true;
        case POS_CHARACTER:
            CharacterClass* class = &self.character_class[data.character.index];
            if (ascii_only)
            {
                for (usz i = current_index; i < current_index + data.character.repeat_count; i++) 
                {
                    if (!class.has(view[i],!case_sensitive)) return false;
                }
                *actually_consumed = data.character.repeat_count;
            }
            else
            {
                usz index = current_index;

                defer *actually_consumed = index - current_index;
                for (usz i = 0; i < data.character.repeat_count; i++) 
                {
                    if (index >= view.len) return false;

                    usz consumed;
                    defer index += consumed;

                    if (try c = utf8::get_character(view[index..],&consumed))
                    {
                        if (!class.has(c, !case_sensitive)) return false;
                    }
                    else
                    {
                        return false;
                    }
                }
            }
            return true;
        case NEG_CHARACTER:
            CharacterClass* class = &self.character_class[data.character.index];
            if (ascii_only)
            {
                for (usz i = current_index; i < current_index + data.character.repeat_count; i++) 
                {
                    if (class.has(view[i],!case_sensitive)) return false;
                }
                *actually_consumed = data.character.repeat_count;
            }
            else
            {
                usz index = current_index;
                defer *actually_consumed = index - current_index;
                for (usz i = 0; i < data.character.repeat_count; i++) 
                {
                    if (index >= view.len) return false;

                    usz consumed;
                    defer index += consumed;

                    if (try c = utf8::get_character(view[index..],&consumed))
                    {
                        if (class.has(c, !case_sensitive)) return false;
                    }
                    else
                    {
                        return false;
                    }
                }
            }
            return true;
        case START:
            if (multiline) 
            {
                return current_index == 0 || (view[current_index - 1] == '\n');
            }
            return current_index == 0;
        case END:
            if (multiline) 
            {
                return current_index == view.len || (view[current_index] == '\n');
            }
            return current_index == view.len;
        case WORD_BOUNDARY:
            if (view.len == 0) 
            {
                return false;
            }
            if (current_index == 0) 
            {
                return is_word_character(view[current_index]);
            }
            if (current_index == view.len) 
            {
                return is_word_character(view[current_index - 1]);
            }
            return  (is_word_character(view[current_index]) && !is_word_character(view[current_index-1])) || 
                    (is_word_character(view[current_index - 1]) && !is_word_character(view[current_index]));
        case NOT_WORD_BOUNDARY:
            if (view.len == 0) 
            {
                return true;
            }
            if (current_index == 0) 
            {
                return !is_word_character(view[current_index]);
            }
            if (current_index == view.len)
            {
                return !is_word_character(view[current_index - 1]);
            }
            return  (is_word_character(view[current_index]) && is_word_character(view[current_index-1])) || 
                    (!is_word_character(view[current_index - 1]) && !is_word_character(view[current_index]));
        case POS_LOOKAHEAD:
            if (current_index >= view.len) return false;
            return self.matches_at(view, current_index, data.sub_automaton_index, &captures);
        case NEG_LOOKAHEAD:
            if (current_index >= view.len) return false;
            return !self.matches_at(view, current_index, data.sub_automaton_index, &captures);
    }
}

<*
    Push the next edge to process to the stack

    @param [&in] self
    @param [&in] ctx          : "The current static contex"
    @param [&in] stack        : "The stack to push the edge to"
    @param edge               : "The current edge being processed"
    @param capture_index      : "The current capture array index"
    @param consumption_length : "How much data was consumed by this edge"
*>
fn void NfaRegex.push_next_edge(
    &self, 
    StaticContext* ctx, 
    List { StackContext }* stack, 
    usz edge, 
    usz index,
    uint capture_index,
    usz consumption_length
) @private
{
    if 
    (
        self.edge_capture_begin[edge] && 
        ctx.allocated_captures[capture_index].begin[self.edge_capture_begin[edge] - 1] == usz.max
    )
    {
        uint next_group = ctx.get_new_capture_array_from(self.num_capture_groups, capture_index);
        ctx.update_capture_begin(next_group, self.edge_capture_begin[edge], index);

        stack.push({
            {
                next_group,
                self.edge_to[edge],
                0
            },
            index + consumption_length
        });
    } 
    else if
    (
        self.edge_capture_end[edge] &&
        ctx.allocated_captures[capture_index].end [self.edge_capture_end[edge] - 1] == usz.max
    ) 
    {
        uint next_group = ctx.get_new_capture_array_from(self.num_capture_groups, capture_index);
        ctx.update_capture_end(next_group, self.edge_capture_end[edge], index);

        stack.push({
            {
                next_group,
                self.edge_to[edge],
                0
            },
            index + consumption_length
        });
    } 
    else 
    {
        ctx.allocated_captures[capture_index].ref_count += 1;

        stack.push({
            {
                capture_index,
                self.edge_to[edge],
                0
            },
            index + consumption_length
        });
    }
}


<*
    Try and get a match starting at the current offset in the view

    @param [&in] self
    @param view: "The string view being matched over"
    @param offset: "The offset in the view to match at"
    @param match_allocator: "The allocator being used to allocate the array of captures"

    @require offset < view.len

    @return? regex::NO_MATCH : "If there is no match starting at the offset"
    @return "A match starting at the offset"
*>
fn Match? NfaRegex.match_in_view(&self, String view, usz offset, Allocator match_allocator) @dynamic 
{
    uint begin_state = self.automaton_begin[0];
    uint end_state = self.automaton_end[0];
    @pool() 
    {
        // Setup the initial context
        StaticContext static_context;
        uint starting_capture_array = static_context.get_new_capture_array(self.num_capture_groups);
        usz* array_begin = static_context.allocated_captures[starting_capture_array].begin;
        usz* array_end = static_context.allocated_captures[starting_capture_array].end;

        for (ushort i = 0 ; i < self.num_capture_groups; i++) 
        {
            array_begin[i] = usz.max;
            array_end[i] = usz.max;
        }

        List { StackContext } context_stack;

        context_stack.push({
            {
                starting_capture_array,
                begin_state,
                0,
            },
            offset
        });

        while (try current_context = context_stack.pop()) 
        {
            uint capture_index = current_context.p.capture_index;
            defer static_context.allocated_captures[capture_index].ref_count -= 1;
            

            uint state_index = current_context.p.state_index;
            ushort edge_index = current_context.p.edge_index;
            usz current_state_begin = self.state_edges_begin[state_index];
            uint edge_count = self.state_edge_count[state_index];
            usz edge_offset = current_state_begin + edge_index;
            usz index = current_context.view_index;

            if (state_index == end_state) return current_context.to_match(static_context.allocated_captures[capture_index], view, self.num_capture_groups, offset, match_allocator);
            
            // Push the next edge if there is one
            if (edge_index + 1 < edge_count) 
            {
                static_context.allocated_captures[capture_index].ref_count += 1;
                context_stack.push({
                    {
                        capture_index,
                        state_index,
                        edge_index + 1
                    },
                    index
                });
            }
            
            usz consumption_length = self.get_min_consumption_length(edge_offset, static_context.allocated_captures[capture_index]);
            
            if (index + consumption_length > view.len) continue;
            
            if (!self.should_transition(edge_offset, index, view, static_context.allocated_captures[capture_index], &consumption_length)) continue;
            
            self.push_next_edge(&static_context, &context_stack, edge_offset, index, capture_index, consumption_length);
        }

        return regex::NO_MATCH?;
    };
}

<*
    Check if the given subautoma matches at the index
    
    @param [&in] self
    @param view                 : "The string view being matched over"
    @param offset               : "The offset in the view to match at"
    @param sub_automaton_index  : "The subautomaton to check"
    @param capture_base         : "The parent capture group array, if there is one"
    @param require_full         : "Does this require a full match?"

    @require offset <= view.len : "Offset is out of bounds of the string"
    @require sub_automaton_index < self.automaton_count : "Invalid subautomaton index"
    @require capture_base == null || capture_base.ref_count > 0 : "The capture group array is deallocated"

    @return "If the sub-automaton matches at the given offset"
*>
fn bool NfaRegex.matches_at(&self, String view, usz offset, usz sub_automaton_index, CaptureEntry* capture_base = null, bool require_full = false) @private
{
    uint begin_state = self.automaton_begin[sub_automaton_index];
    uint end_state = self.automaton_end[sub_automaton_index];
    @pool() 
    {
        // Setup the initial context
        StaticContext static_context;
        uint starting_capture_array = static_context.get_new_capture_array(self.num_capture_groups);
        usz* array_begin = static_context.allocated_captures[starting_capture_array].begin;
        usz* array_end = static_context.allocated_captures[starting_capture_array].end;
        
        for (ushort i = 0 ; i < self.num_capture_groups; i++) 
        {
            array_begin[i] = capture_base ? capture_base.begin[i] : usz.max;
            array_end[i] = capture_base ? capture_base.end[i] : usz.max;
        }

        List { StackContext } context_stack;

        context_stack.push({
            {
                starting_capture_array,
                begin_state,
                0,
            },
            offset
        });

        while (try current_context = context_stack.pop()) 
        {    
            uint capture_index = current_context.p.capture_index;
            defer static_context.allocated_captures[capture_index].ref_count -= 1;
            
            uint state_index = current_context.p.state_index;
            ushort edge_index = current_context.p.edge_index;
            usz current_state_begin = self.state_edges_begin[state_index];
            uint edge_count = self.state_edge_count[state_index];
            usz edge_offset = current_state_begin + edge_index;
            usz index = current_context.view_index;

            if (state_index == end_state) {
                if (require_full && index != view.len)
                {
                    continue;
                }
                return true;
            }

            // Push the next edge if there is one
            if (edge_index + 1 < edge_count) 
            {
                static_context.allocated_captures[capture_index].ref_count += 1;
                context_stack.push({
                    {
                        capture_index,
                        state_index,
                        edge_index + 1
                    },
                    index
                });
            }
            
            usz consumption_length = self.get_min_consumption_length(edge_offset, static_context.allocated_captures[capture_index]);
            
            if (index + consumption_length > view.len) continue;
            
            if (!self.should_transition(edge_offset, index, view, static_context.allocated_captures[capture_index], &consumption_length)) continue;

            self.push_next_edge(&static_context, &context_stack, edge_offset, index, capture_index, consumption_length);
        }

        return false;
    };
}

<*
    Check if the regex matches the entirety of the given string

    @param [&in] self
    @param view : "The string to match"

    @return "Does the regex match the entire string"
*>
fn bool NfaRegex.matches(&self, String view) @dynamic
{
    return self.matches_at(view, 0, 0, require_full: true);
}

fn void NfaRegex.free(&self) @dynamic 
{
    allocator::free(self.allocator, self.automaton_begin);
    allocator::free(self.allocator, self.automaton_end);
    allocator::free(self.allocator, self.state_edges_begin);
    allocator::free(self.allocator, self.state_edge_count);
    allocator::free(self.allocator, self.edge_to);
    allocator::free(self.allocator, self.transition_type);
    allocator::free(self.allocator, self.edge_capture_begin);
    allocator::free(self.allocator, self.edge_capture_end);
    allocator::free(self.allocator, self.edge_associated_data);
    foreach (&class : self.character_class)
    {
        class.free();
    }
    allocator::free(self.allocator, self.character_class);
    allocator::free(self.allocator, self.strings);
}