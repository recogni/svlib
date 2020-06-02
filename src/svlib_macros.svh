//=============================================================================
//  @brief macro definitions
//  @author Jonathan Bromley, Verilab (www.verilab.com)
//=============================================================================
//
//                      svlib SystemVerilog Utilities Library
//
// @File: svlib_macros.svh
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
`ifndef SVLIB_MACROS__DEFINED
`define SVLIB_MACROS__DEFINED

//=============================================================================
// This file defines various macros for svLib. Users should
// `include this file in any source file that uses any of these
// macros.  Doing so will NOT compile or import any of the svLib
// packages, which must be compiled separately and imported into
// user code as required.
// Note that the macros should normally be `include-d at the
// outermost level, whereas packages should always be imported
// into a module, interface or package.
//=============================================================================

// foreach_enum
// ------------
// A loop construct to iterate over the enumerator values of
// any enumeration type. It takes two or three arguments.
// * The first argument is the enumeration type, which should
//   always be a "typedef" name.
// * The second argument names a local iterator variable of
//   the enumeration type. It is this variable that is scanned
//   over the possible values, in declaration order.
// * The optional third argument names a local iterator variable
//   that counts from 0 to num-1, where num is the number of
//   different enumerator names in the enumeration type. If you
//   do not provide this name, the macro provides the long and
//   unlikely name "__foreach_enum_position_iterator__".
//   Unfortunately, such a variable must be declared - it is
//   required for the macro's operation.
// The macro acts in every way like a normal procedural loop;
// it controls exactly one procedural statement, or a begin..end.
// Typical usage patterns might be:
//    typedef enum {A, B, C} myEnum_e;
//    ...
//    `foreach_enum(myEnum_e, m, i)
//      $display("%0d: %s = %0d", i, m.name, m);
//    `foreach_enum(myEnum_e, m) begin
//      ... do something with 'm' ...
//    end
// Please note that this macro CANNOT be used in randomization constraints.
//-------------------------------------------------------------------
`define foreach_enum(E,e,i=__foreach_enum_position_iterator__)      \
  for (E e = e.first, int i=0; i<e.num; e=e.next, i++)
//-------------------------------------------------------------------


// foreach_line
// ------------
// A loop construct to iterate over the lines of a plain-text
// file that has already been opened for reading. It takes
// three mandatory arguments and a fourth optional argument.
// * The first argument 'fid' is the Verilog file identifier
//   for the file to be read; it must have already been opened
//   using $fopen("file_name", "r") or similar.
// * The second argument 'line' names a string variable, declared
//   locally within the loop, which will hold each line of the
//   file in turn.
// * The third argument 'linenum' names an int variable, declared
//   locally within the loop, which will hold the line number
//   of the current line within the file.
// * The optional fourth argument 'start' is the starting value
//   of the 'linenum' counter. It defaults to 1, but you can
//   replace it to account for the possibility that some lines of
//   the open file might already have been consumed by other code.
// On each trip around the loop, the next line in the file is
// made available in 'line'. The line includes its trailing newline
// character.
// As with `forenum, this macro acts as a normal loop construct.
//-------------------------------------------------------------------
`define foreach_line(fid,line,linenum,start=1)                        \
  for (                                                               \
    int \macro%%FILE%%ID =(fid), int linenum=(start), string line=""; \
        $fgets(line, \macro%%FILE%%ID ) > 0;                          \
        linenum++                                                     \
  )
//-------------------------------------------------------------------


// SVLIB_DOM_UTILS_BEGIN
// SVLIB_DOM_FIELD_OBJECT
// SVLIB_DOM_FIELD_STRING
// SVLIB_DOM_UTILS_END
// ----------------------
// Macros to automate the creation of methods fromDOM and toDOM
// of any class that requires them. See the section "Document
// Object Model" in the User's Guide.
//
//-------------------------------------------------------------------
`define SVLIB_DOM_UTILS_BEGIN(T)                                    \
  function void fromDOM(cfgNodeMap dom);                            \
    if (dom != null)                                                \
      __svlib_dom_superfunction__(1, "", dom);                      \
  endfunction                                                       \
  function cfgNodeMap toDOM(string name);                           \
    cfgNodeMap dom;                                                 \
    __svlib_dom_superfunction__(0, name, dom);                      \
    return dom;                                                     \
  endfunction                                                       \
  protected function void __svlib_dom_superfunction__(              \
      int purpose, string name, inout cfgNodeMap dom                \
    );                                                              \
    case (purpose)                                                  \
    0 : // toDOM(name);                                             \
      begin                                                         \
        if (dom == null) dom = cfgNodeMap::create(name);            \
      end                                                           \
    1 : // fromDOM(cfgNodeMap dom);                                 \
      begin                                                         \
        if (dom == null) return;                                    \
      end                                                           \
    endcase
//-------------------------------------------------------------------
`define SVLIB_DOM_FIELD_OBJECT(MEMBER)                              \
  case (purpose)                                                    \
  0 : // toDOM(name);                                               \
    begin                                                           \
      dom.addNode(MEMBER.toDOM(`"MEMBER`"));                        \
    end                                                             \
  1 : // fromDOM(cfgNodeMap dom);                                   \
    begin                                                           \
      cfgNodeMap nd;                                                \
      if ($cast(nd, dom.lookup(`"MEMBER`"))) begin                  \
        if (nd != null) begin                                       \
          if (MEMBER == null) MEMBER = new;                         \
          MEMBER.fromDOM(nd);                                       \
        end                                                         \
      end                                                           \
    end                                                             \
  endcase
//-------------------------------------------------------------------
`define SVLIB_DOM_FIELD_STRING(MEMBER)                              \
  case (purpose)                                                    \
  0 : // toDOM(name);                                               \
    begin                                                           \
      dom.addNode(cfgScalarString::createNode(`"MEMBER`", MEMBER)); \
    end                                                             \
  1 : // fromDOM(cfgNodeMap dom);                                   \
    begin                                                           \
      cfgNodeScalar   MEMBER``__n;                                  \
      cfgScalarString MEMBER``__s;                                  \
      if ($cast(MEMBER``__n, dom.childByName(`"MEMBER`")))          \
        if (MEMBER``__n != null)                                    \
          if ($cast(MEMBER``__s, MEMBER``__n.value))                \
            MEMBER = MEMBER``__s.get();                             \
    end                                                             \
  endcase
//-------------------------------------------------------------------
`define SVLIB_DOM_FIELD_INT(MEMBER)                                 \
  case (purpose)                                                    \
  0 : // toDOM(name);                                               \
    begin                                                           \
      dom.addNode(cfgScalarInt::createNode(                         \
                                  `"MEMBER`", MEMBER));             \
    end                                                             \
  1 : // fromDOM(cfgNodeMap dom);                                   \
    begin                                                           \
      cfgNodeScalar MEMBER``__n;                                    \
      cfgScalarInt  MEMBER``__s;                                    \
      if ($cast(MEMBER``__n, dom.childByName(`"MEMBER`")))          \
        if (MEMBER``__n != null) begin                              \
          string str = MEMBER``__n.sformat();                       \
          int neg = (str.substr(0,0) == "-");                       \
          if(neg)                                                   \
            str = str.substr(1, str.len()-1);                       \
          $cast(MEMBER``__s, cfgScalarInt::create(str.atoi()));     \
          MEMBER = (neg)?(-1*MEMBER``__s.get()):MEMBER``__s.get();  \
        end                                                         \
    end                                                             \
  endcase
//-------------------------------------------------------------------
`define SVLIB_DOM_UTILS_END                                         \
  endfunction
//-------------------------------------------------------------------


// SVLIB_CFG_NODE_UTILS
// -----------------
// DO NOT USE this macro unless you are writing an extension of an
// svLib DOM node class. See the section "Writing custom extensions
// of svLib" in the Developer's Guide.
//-------------------------------------------------------------------
`define SVLIB_CFG_NODE_UTILS(T)                                     \
  protected function new(); endfunction                             \
  static function T create(string name = "");                       \
    T me = Obstack#(T)::obtain();                                   \
    me.name = name;                                                 \
    me.parent = null;                                               \
    return me;                                                      \
  endfunction
//-------------------------------------------------------------------

`endif
