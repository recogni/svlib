//=============================================================================
//  @brief  Implementations (bodies) of extern functions of Pathname
//  @author Jonathan Bromley, Verilab (www.verilab.com)
//=============================================================================
//
//                      svlib SystemVerilog Utilities Library
//
// @File: svlib_impl_File.svh
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
// Render some subset of the path. Use first<0 if you
// want the / volume indicator to appear as a prefix,
// if the path is absolute.
function string Pathname::render(int first, int last);
  bit volPrefix;
  string result;
  if (first < 0) begin
    first = 0;
    volPrefix = absolute;
  end
  if ((first < comps.size()) && (last >= first)) begin
    if (last >= comps.size()) last = comps.size()-1;
    result = separator.sjoin(comps[first:last]);
  end
  if (volPrefix) begin
    result = {volume(), result};
  end
  return result;
endfunction

function Pathname Pathname::create(string s = "");
  Pathname p = Obstack#(Pathname)::obtain();
  p.set(s);
  return p;
endfunction

function string Pathname::get();
  return render(-1, comps.size()-1);
endfunction

function void Pathname::set(string path);
  Str value = Str::create(path);
  qs components = value.split("/", 0);
  absolute = (value.first("/") == 0);
  comps.delete();
  foreach (components[i])
    if (components[i] != "")
      comps.push_back(components[i]);
endfunction

function void Pathname::appendPN(Pathname tailPN);
  if (tailPN.absolute) begin
    // Ignore previous contents of this
    this.absolute = 1;
    this.comps = tailPN.comps;
  end
  else begin
    this.comps = {this.comps, tailPN.comps};
  end
endfunction

function void Pathname::append(string tail);
  Pathname tailPN = Obstack#(Pathname)::obtain();
  tailPN.set(tail);
  appendPN(tailPN);
  Obstack#(Pathname)::relinquish(tailPN);
endfunction

function Pathname Pathname::copy();
  Pathname result = Obstack#(Pathname)::obtain();
  result.comps = this.comps;
  result.absolute = this.absolute;
  return result;
endfunction

function void Pathname::purge();
  comps = {};
  absolute = 0;
endfunction

function bit Pathname::isAbsolute();
  return absolute;
endfunction

function string Pathname::dirname(int backsteps=1);
  return render(-1, comps.size()-(1+backsteps));
endfunction

function string Pathname::extension();
  string result = comps[$];
  Str str = Obstack#(Str)::obtain();
  int dotpos;
  str.set(result);
  dotpos = str.last(".");
  if (dotpos < 0) begin
    return "";
  end
  else begin
    Obstack#(Str)::relinquish(str);
    return result.substr(dotpos, result.len()-1);
  end
endfunction

function string Pathname::basename();
  string s = extension();
  int extLen = s.len();
  s = get();
  return s.substr(0, s.len() - (extLen + 1));
endfunction

function string Pathname::tail(int backsteps=1);
  return render(comps.size()-backsteps, comps.size()-1);
endfunction

function string Pathname::volume();  // always '/' on *nix
  return "/";
endfunction
