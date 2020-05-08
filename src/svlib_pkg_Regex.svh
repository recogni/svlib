//=============================================================================
//  @brief  Regex class and methods
//  @author Jonathan Bromley, Verilab (www.verilab.com)
//=============================================================================
//
//                      svlib SystemVerilog Utilities Library
//
// @File: svlib_pkg_Regex.svh
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

//=============================================================================
// class definitions

class Regex extends svlibBase;

  typedef enum {NOCASE=regexNOCASE, NOLINE=regexNOLINE} regexOptions;

  //---------------------------------------------------------------------------
  // Protected functions and members

  protected int nMatches;
  protected int lastError;
  protected int matchList[20];
  protected Str runStr;

  //protected int     compiledRegexKey;    // for lookup on C side
  //protected chandle compiledRegexHandle; // check on C-side pointer

  protected int    options;
  protected string text;

  // forbid construction
  protected function new(); 
            endfunction: new

  extern protected virtual function void   purge();
  extern protected virtual function int    match_subst(string substStr);

  //---------------------------------------------------------------------------

  extern static  function Regex  create (string s = "", int options=0);
  // Set the regular expression string
  extern virtual function void   setRE  (string s);
  // Set the options (as a bitmap)
  extern virtual function void   setOpts(int options);
  // Set the test string
  extern virtual function void   setStr (Str s);
  extern virtual function void   setStrContents (string s);

  // Retrieve the regex string
  extern virtual function string getRE  ();
  // Retrieve the option bitmap
  extern virtual function int    getOpts();
  // Retrieve the test string
  extern virtual function Str    getStr();
  extern virtual function string getStrContents();

  // Clone this regex into another, preserving all values
  extern virtual function Regex  copy   ();

  // Get the error code for the most recent error. 
  // Checks the RE for validity, if not done already.    
  extern virtual function int    getError();
  // Get a string representation of the error
  extern virtual function string getErrorString();

  // Run the RE on a sample string, skipping over the first startPos characters
  extern virtual function int    test   (Str s, int startPos=0);
  // Run the RE again on the same sample string, with different start position
  extern virtual function int    retest (int startPos);

  // From the most recent test, find how many matches there were (0=no match).
  // The whole match counts as 1; each submatch/group adds one.
  extern virtual function int    getMatchCount ();
  // For a given match (0=full) get the start position of that match
  extern virtual function int    getMatchStart (int match = 0);
  // For a given match (0=full) get the length of that match
  extern virtual function int    getMatchLength(int match = 0);
  // Extract a given match from the sample string, returns "" if no match
  extern virtual function string getMatchString(int match = 0);

  extern virtual function int    subst(string substStr, int startPos = 0);
  extern virtual function int    substAll(string substStr, int startPos = 0);
  
  // Like Perl's split. Leaves string contents untouched;
  // returns queue of split strings
  extern virtual function qs     split(int limit = 0);

endclass: Regex

//=============================================================================
// Function definitions that are not part of classes

// regex_match ================================================================
function automatic Regex regex_match(string haystack, string needle, int options=0);
  Regex re;
  Str   s;
  bit   found;
  re  = Obstack#(Regex)::obtain();
  s   = Obstack#(Str)::obtain();
  s.set(haystack);
  re.setRE(needle);
  re.setStr(s);
  re.setOpts(options);
  regex_match_check_RE_valid: 
    assert (re.getError()==0) else
      $error("Bad RE \"%s\": %s", needle, re.getErrorString());
  found = re.retest(0);
  if (found)
    return re;
  // Return the unwanted objects to their obstacks
  Obstack#(Str)::relinquish(s);
  Obstack#(Regex)::relinquish(re);
  return null;
endfunction: regex_match

// regex_split =================================================================
function automatic qs regex_split(string source, string pattern, int limit=0);
  Regex re;
  Str   s;
  qs    result;
  re  = Obstack#(Regex)::obtain();
  s   = Obstack#(Str)::obtain();
  s.set(source);
  re.setRE(pattern);
  re.setStr(s);
  regex_split_check_RE_valid: 
    assert (re.getError()==0) else
      $error("Bad RE \"%s\": %s", pattern, re.getErrorString());
  result = re.split(limit);
  Obstack#(Str)::relinquish(s);
  Obstack#(Regex)::relinquish(re);
  return result;
endfunction : regex_split

// scanVerilogInt =============================================================
function automatic bit scanVerilogInt(string s, inout logic signed [63:0] result);
  bit ok;
  Regex re;
  Str str;
  str = Obstack#(Str)::obtain();
  str.set(s);
  
  // First sieve: is it syntactically anything like an integer?
  // The RE also strips leading and trailing underscores from 
  // the digit string.
  re = Obstack#(Regex)::obtain();
  re.setRE({
    "^[[:space:]]*",                        // Arbitrary leading space
    "(-?)[[:space:]]*",                     // Optional minus sign in $1
  // 1--1
    "(([[:digit:]]+)?'(s?)([hxdob]))?",     // $3=nBits, $4=signing, $5=radix
  //  3------------3  4--45-------5
  // 2-----------------------------2
    "_*([[:xdigit:]xz_]*[[:xdigit:]xz])_*", // $6=digit string
  //   6------------------------------6
    "[[:space:]]*$"                         // Arbitrary trailing space
  });
  
  re.setOpts(Regex::NOCASE);
  
  ok = re.test(str);
  
  if (ok) begin
    logic signed [63:0] value;
    string nBitsStr, radixLetter, valueStr;
    int    nBits;
    bit    negate, isSigned;
    negate      = re.getMatchLength(1) > 0;
    nBitsStr    = re.getMatchString(3);
    isSigned    = re.getMatchLength(4) > 0;
    radixLetter = re.getMatchString(5);
    valueStr    = re.getMatchString(6);
    
    if (nBitsStr == "")
      nBits = 32;
    else
      nBits = nBitsStr.atoi;

    ok = scanUint64(nBits, isSigned, radixLetter, valueStr, value);
    if (ok) begin
      // negate if necessary, so sign-ext is correct
      if (negate) value = -value;
      result = value;
    end
  end
  
  // dispose of temp objects
  Obstack#(Regex)::relinquish(re);
  Obstack#(Str)::relinquish(str);
  
  return ok;
  
endfunction: scanVerilogInt

//=============================================================================
/////////////////// IMPLEMENTATIONS OF EXTERN CLASS METHODS ///////////////////

`include "svlib_impl_Regex.svh"
