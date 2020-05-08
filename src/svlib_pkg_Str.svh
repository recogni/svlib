//=============================================================================
//  @brief  Package of classes and functions for Str operations
//  @author Jonathan Bromley, Verilab (www.verilab.com)
//=============================================================================
//
//                      svlib SystemVerilog Utilities Library
//
// @File: svlib_pkg_Str.svh
//
// Copyright 2014 Verilab, Inc.
//
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.
//=============================================================================
// Str: various string manipulations.
// Many functions come in two flavors:
// - a package version named str_XXX that takes a string value,
//   does some work on it and returns a result; and
// - an object version named .XXX that operates on a stored
//   Str object, possibly returning a result and possibly
//   modifying the stored object.
//
//=============================================================================

//=============================================================================
// Class definitions
class Str extends svlibBase;

  typedef enum {NONE, LEFT, RIGHT, BOTH} side_enum;
  typedef enum {START, END} origin_enum;


  //---------------------------------------------------------------------------
  // Protected functions and members

  // constructor so that users can't call it
  protected function new();
            endfunction: new

  protected function void purge();
              setClean("");
            endfunction: purge

  protected string value;
  protected function void setClean(string s);
            // Zap all to initial state except for "value"
              value = s;
            endfunction: setClean

  extern protected function void get_range_positions(
                     int p, int n, origin_enum origin=START,
                     output int L, output int R
                   );
  extern protected function void clip_to_bounds(inout int n);

  //---------------------------------------------------------------------------
  // Save a string as an object so that further manipulations can
  // be performed on it.  Get and set the object's string value.
  extern static  function Str    create(string s = "");
  extern virtual function string get   ();
  extern virtual function Str    copy  ();
  extern virtual function int    len   ();

  extern virtual function void   set   (string s);
  extern virtual function void   append(string s);

  // Find the first occurrence of substr in s, ignoring the specified
  // number of characters from the starting point.
  // If a match is found, return the index of the leftmost
  // character of the match.
  // If no match is found, return -1.
  extern virtual function int    first (string substr, int ignore=0);
  extern virtual function int    last  (string substr, int ignore=0);

  // Split a string on every occurrence of a given character
  extern virtual function qs     split (string splitset="", bit keepSplitters=0);

  // Use the Str object's contents to join adjacent elements of the
  // queue of strings into a single larger string. For example, if the
  // Str object 's' contains "XX" then
  //    s.sjoin({"a", "b", "c"})
  // would yield the string "a, b, c"
  extern virtual function string sjoin (qs strings);

  // Get a range (substring). The starting position 'p' is an anchor point,
  // like an I-beam cursor, just to the left of the specified character.
  // If 'origin' is START, count 'p' from the left end of the string,
  // with its value increasing towards the right. If 'origin' is END,
  // count 'p' from the right end of the string, with its value increasing
  // towards the left.
  // The range size 'n' specifies a count of characters to the right of 'p',
  // or to the left of 'p' if 'n' is negative; n==0 specifies an empty string.
  // If p<0, treat it as the corresponding number of character positions
  // beyond the end (or start) of the string.
  // Clip result to smaller than n if necessary so that the result remains
  // entirely within the bounds of the original string.
  extern virtual function string range (int p, int n, origin_enum origin=START);

  // Replace the range p/n with some other string, not necessarily same length.
  // If n==0 this is an insert operation.
  extern virtual function void   replace(string rs, int p, int n, origin_enum origin=START);

  // Trim a string (remove leading and/or trailing whitespace)
  extern virtual function void   trim  (side_enum side=BOTH);

  // Strips the string of any character found in the ~chars~ string. If ~chars~
  // is not present, all blanks are removed from the string."
  // Default characters to strip are: space, \t (tab=x09), \n (newline=x0A),
  //  \13 (vertical-tab=x0B), \14 (formfeed=x0C), \15 (carriage-return=x0D),
  //  \240 (nonbreaking-space=160=xA0), \177 (rubout=x7F)
  extern virtual function void   strip (string chars=" \t\n\13\14\15\240\177");
     
  // Pad a string to width with spaces on left/right/both
  extern virtual function void   pad   (int width, side_enum side=BOTH);

  // Quote a string so that it becomes a valid SystemVerilog string literal,
  // complete with enclosing double-quotes unless the "suppress" arg is set.
  // All special characters in the string are backslash-escaped appropriately.
  extern virtual function void   quote (bit suppressEnclosingQuotes = 0);


endclass: Str

//=============================================================================


//=============================================================================
// Function definitions that are not class-based


// isSpace ====================================================================
function automatic bit isSpace(byte unsigned ch);
  return (ch inside {"\t", "\n", " ", 13, 160});  // CR, nbsp
endfunction: isSpace

// str_sjoin ==================================================================
function automatic string str_sjoin(qs elements, string joiner);
  Str str = Obstack#(Str)::obtain();
  str.set(joiner);
  str_sjoin = str.sjoin(elements);
  Obstack#(Str)::relinquish(str);
endfunction: str_sjoin

// str_repeat =================================================================
function automatic string str_repeat(string s, int n);
  if (n<=0) return "";
  return {n{s}};
endfunction: str_repeat

// str_trim ===================================================================
function automatic string str_trim(string s, Str::side_enum side=Str::BOTH);
  Str str = Obstack#(Str)::obtain();
  str.set(s);
  str.trim(side);
  str_trim = str.get();
  Obstack#(Str)::relinquish(str);
endfunction: str_trim

// str_strip ===================================================================
// Strip a string of any character found in the supplied ~chars~ string. 
// Default characters to strip are: space, \t (tab=x09), \n (newline=x0A),
//  \13 (vertical-tab=x0B), \14 (formfeed=x0C), \15 (carriage-return=x0D),
//  \240 (nonbreaking-space=160=xA0), \177 (rubout=x7F)
function automatic string str_strip(string s, string chars=" \t\n\13\14\15\240\177");
  Str str = Obstack#(Str)::obtain();
  str.set(s);
  str.strip(chars);
  str_strip = str.get();
  Obstack#(Str)::relinquish(str);
endfunction: str_strip

// str_pad ====================================================================
function automatic string str_pad(string s, int width, Str::side_enum side=Str::BOTH);
  Str str = Obstack#(Str)::obtain();
  str.set(s);
  str.pad(width, side);
  str_pad = str.get();
  Obstack#(Str)::relinquish(str);
endfunction: str_pad

// str_quote ==================================================================
function automatic string str_quote(string s, bit suppressEnclosingQuotes = 0);
  Str str = Obstack#(Str)::obtain();
  str.set(s);
  str.quote(suppressEnclosingQuotes);
  str_quote = str.get();
  Obstack#(Str)::relinquish(str);
endfunction: str_quote

// str_replace ================================================================
  // Replace the range p/n with some other string, not necessarily same length.
  // If n==0 this is an insert operation.
function automatic string str_replace(string s, string rs, int p, int n,
                                      Str::origin_enum origin=Str::START);
  Str str = Obstack#(Str)::obtain();
  str.set(s);
  str.replace(rs, p, n, origin);
  str_replace = str.get();
  Obstack#(Str)::relinquish(str);
endfunction: str_replace

//=============================================================================
/////////////////// IMPLEMENTATIONS OF EXTERN CLASS METHODS ///////////////////

`include "svlib_impl_Str.svh"
