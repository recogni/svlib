//=============================================================================
//  @brief  Implementations (bodies) of extern functions in class Enum
//  @author Jonathan Bromley, Verilab (www.verilab.com)
//=============================================================================
//
//                      svlib SystemVerilog Utilities Library
//
// @File: svlib_impl_Enum.svh
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
// svlib_Enum_impl.sv
// ------------------
// Implementations (bodies) of extern functions in class Enum
//
// This file is `include-d into svlib_Enum_pkg.sv and
// should not be used in any other context.

function EnumUtils::INDEX EnumUtils::index(BASE b);
  bit [$bits(BASE)-1:0] b2;
  // Get 1s in all 1/0 bit positions, X in all X/Z positions
  b2 = b | ~b;
  return {~b2, b};
endfunction

function void EnumUtils::m_build();
  ENUM e = e.first;
  m_maxNameLength = 0;
  for (int pos=0; pos<e.num; pos++) begin
    string nm = e.name;
    m_all_values.push_back(e);
    m_map[nm] = e;
    m_pos[index(e)] = pos;
    if (nm.len > m_maxNameLength)
      m_maxNameLength = nm.len;
    e = e.next;
  end
  m_built = 1;
endfunction

function EnumUtils::qe EnumUtils::allValues();
  if (!m_built) m_build();
  return m_all_values;
endfunction

function bit EnumUtils::hasName(string s);
  if (!m_built) m_build();
  return m_map.exists(s);
endfunction

function bit EnumUtils::hasValue(EnumUtils::BASE b);
  if (!m_built) m_build();
  return m_pos.exists(index(b));
endfunction

function EnumUtils::ENUM EnumUtils::fromName(string s);
  ENUM result; // default init value
  if (!m_built) m_build();
  if (hasName(s))
    result = m_map[s];
  return result;
endfunction

function int EnumUtils::pos(BASE b);
  if (hasValue(b))
    return m_pos[index(b)];
  else
    return -1;
endfunction

function int EnumUtils::maxNameLength();
  if (!m_built) m_build();
  return m_maxNameLength;
endfunction

function EnumUtils::ENUM EnumUtils::match(EnumUtils::BASE b, bit requireUnique = 0);
  qe matchList;
  svlibErrorManager emgr = error_getManager();
  if (!m_built) m_build();
  matchList = m_all_values.find() with(b ==? item);
  if (matchList.size() == 0) begin
    emgr.submit(-1, $sformatf("EnumUtils::match() found no match for value 'b%b", b));
    return ENUM'(b);
  end
  else if (matchList.size() > 1 && requireUnique) begin
    emgr.submit(-2, $sformatf("EnumUtils::match() found multiple matches for value 'b%b", b));
    return ENUM'(b);
  end
  else begin
    emgr.submit(0, "");
    return matchList[0];
  end
endfunction
