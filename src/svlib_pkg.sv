//=============================================================================
//  @brief  svlib_pkg imports and includes
//  @author Jonathan Bromley, Verilab (www.verilab.com)
//=============================================================================
//
//                      svlib SystemVerilog Utilities Library
//
// @File: svlib_pkg.sv
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
`ifndef SVLIB_PKG_DEFINED
`define SVLIB_PKG_DEFINED

`include "svlib_macros.svh"
`include "svlib_private_base_pkg.svh"

package svlib_pkg;

  import svlib_private_base_pkg::*;

  `include "svlib_pkg_Error.svh"
  `include "svlib_pkg_Str.svh"
  `include "svlib_pkg_Regex.svh"
  `include "svlib_pkg_Enum.svh"
  `include "svlib_pkg_Sys.svh"
  `include "svlib_pkg_File.svh"
  `include "svlib_pkg_Cfg.svh"
  `include "svlib_pkg_Sim.svh"

endpackage

`endif
