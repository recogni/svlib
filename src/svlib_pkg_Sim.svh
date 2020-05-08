//=============================================================================
//  @brief  Simulator interaction classes and functions
//  @author Jonathan Bromley, Verilab (www.verilab.com)
//=============================================================================
//
//                      svlib SystemVerilog Utilities Library
//
// @File: svlib_pkg_Sim.svh
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

class Simulator extends svlibBase;

  protected string product;
  protected string version;
  protected qs     cmdLine;
  protected static Simulator singleton;

  static function Simulator get_instance();
    if (singleton == null) begin
      singleton = Obstack#(Simulator)::obtain();
      singleton.populate();
    end
    return singleton;
  endfunction : get_instance
  
  protected function void populate();
    chandle hnd;
    hnd = svlib_dpi_imported_getVlogInfo(product, version);
    forever begin
      string s = svlib_dpi_imported_getVlogInfoNext(hnd);
      if (hnd == null) break;
      cmdLine.push_back(s);
    end
  endfunction : populate
  
  protected virtual function void purge(); endfunction
  
  static function string getToolName();
    Simulator sim = Simulator::get_instance();
    return sim.product;
  endfunction : getToolName
  static function string getToolVersion();
    Simulator sim = Simulator::get_instance();
    return sim.version;
  endfunction : getToolVersion
  static function qs getCmdLine();
    Simulator sim = Simulator::get_instance();
    return sim.cmdLine;
  endfunction : getCmdLine

endclass : Simulator

