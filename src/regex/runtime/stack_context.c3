<*
    This module contains common stack code for the automata implementation on both the compiled and non-compiled versions
*>
module regex::runtime::stack_context;

import std::collections::list;

<* An array of captures on referenced to by the stack, copy on write *>
struct CaptureEntry 
{
    <* reference count this capture array *>
    uint ref_count;
    usz* begin;
    usz* end;
}


<* Context that remains the same while running a regex *>
struct StaticContext 
{
    List { CaptureEntry } allocated_captures;
}

<*
    Get a new capture array for storing on the stack
    
    @param [&in] self
    @param num_capture_groups : "How many capture groups does the calling regex have"

    @return "The index of a new capture group array in the capture group arrays table, this index being storable on the stack"
*>
fn uint StaticContext.get_new_capture_array(&self, ushort num_capture_groups) 
{
    foreach (i, &entry : self.allocated_captures) 
    {
        if (!entry.ref_count) 
        {
            entry.ref_count = 1;
            entry.begin = mem::temp_array(usz, num_capture_groups);
            entry.end = mem::temp_array(usz, num_capture_groups);
            return (uint)i;
        }
    }
    CaptureEntry entry = {
        1,
        mem::temp_array(usz, num_capture_groups),
        mem::temp_array(usz, num_capture_groups)
    };
    self.allocated_captures.push(entry);
    return (uint)(self.allocated_captures.len() - 1);
}

<*
    Get a new capture array copying a previous capture array group

    @param [&in] self
    @param num_capture_groups         : "How many capture groups does the calling regex have"
    @param originalCaptureGroupsIdx : "Which capture group array is being copied"

    @require originalCaptureGroupsIdx < self.allocated_captures.len()        : "Original capture group array is out of bounds"
    @require self.allocated_captures[originalCaptureGroupsIdx].ref_count != 0 : "Original capture group array is deallocated"

    @return "The index of a new capture group array in the capture group arrays table, with the captures copied from the original capture group array"
*>
fn uint StaticContext.get_new_capture_array_from(&self, ushort num_capture_groups, uint originalCaptureGroupsIdx) 
{
    uint array_index = self.get_new_capture_array(num_capture_groups);
    usz* current_array_begin = self.allocated_captures[originalCaptureGroupsIdx].begin;
    usz* current_array_end = self.allocated_captures[originalCaptureGroupsIdx].end;
    usz* next_array_begin = self.allocated_captures[array_index].begin;
    usz* next_array_end = self.allocated_captures[array_index].end;
    for (ushort i = 0 ; i < num_capture_groups; i++) {
        next_array_begin[i] = current_array_begin[i];
        next_array_end[i] = current_array_end[i];
    }
    return array_index;
}

<*
    Update a capture group begin index

    @param [&in] self
    @param groupsIdx : "The index of the capture group array being modified"
    @param group     : "The capture group being modified, this is 1 indexed"
    @param begin     : "The updated value for the begin position of the capture group"

    @require groupsIdx < self.allocated_captures.len()        : "Capture group array is out of bounds"
    @require self.allocated_captures[groupsIdx].ref_count != 0 : "Capture group array is deallocated"
*>
fn void StaticContext.update_capture_begin(&self, uint groupsIdx, ushort group, usz begin) 
{
    usz* array_begin = self.allocated_captures[groupsIdx].begin;
    array_begin[group-1] = begin;
} 

<*
    Update a capture group end index

    @param [&in] self
    @param groupsIdx : "The index of the capture group array being modified"
    @param group     : "The capture group being modified, this is 1 indexed"
    @param end       : "The updated value for the begin position of the capture group"

    @require groupsIdx < self.allocated_captures.len()        : "Capture group array is out of bounds"
    @require self.allocated_captures[groupsIdx].ref_count != 0 : "Capture group array is deallocated"
*>
fn void StaticContext.update_capture_end(&self, uint groupsIdx, ushort group, usz end) 
{
    usz* array_end = self.allocated_captures[groupsIdx].end;
    array_end[group-1] = end;
} 

<* Designed such that the stack is only consistent of 128 bit values *>
bitstruct PackedStackContext : ulong 
{
    uint   capture_index  : 0 .. 23;
    uint   state_index    : 24 .. 47;
    ushort edge_index     : 48 .. 63;
}

struct StackContext
{
    PackedStackContext p;
    usz view_index;
}

<*
    Return a match at the current position with the current capture groups

    @param self
    @param entry                : "The current capture group array"
    @param view                 : "The string being matched over"
    @param num_capture_groups     : "The number of capture groups in this regex"
    @param start_index           : "The index in the view that the regex started matching from"
    @param [&in] match_allocator : "An allocator to allocate the match's begin and end arrays from"

    @require start_index < view.len      : "The start index is invalid"
    @require self.view_index <= view.len : "The current view index is invalid"

    @return "A match at the given position"
*>
fn Match StackContext.to_match(self, CaptureEntry entry, String view, ushort num_capture_groups, usz start_index, Allocator match_allocator)
{
    usz[] begin = allocator::new_array(match_allocator, usz, (usz)num_capture_groups + 1);
    usz[] end = allocator::new_array(match_allocator, usz, (usz)num_capture_groups + 1);
    for (usz i = 0; i < num_capture_groups; i++) 
    {
        begin[i+1] = entry.begin[i];
        end[i+1] = entry.end[i];
    }
    begin[0] = start_index;
    end[0] = self.view_index;
    return {
        match_allocator,
        view,
        begin,
        end,
        num_capture_groups + 1
    };
}