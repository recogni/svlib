//=============================================================================
//  @brief  
//  @author Jonathan Bromley, Verilab (www.verilab.com)
//=============================================================================
//
//                      svlib SystemVerilog Utilities Library
//
// @File: svlib_dpi_imports.svh
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
`include "svlib_shared_c_sv.h"

import "DPI-C" function string  svlib_dpi_imported_getCErrStr (input int errnum);
import "DPI-C" function int     svlib_dpi_imported_saBufNext(inout  chandle hnd,
                                                output string  path );

import "DPI-C" function string  svlib_dpi_imported_regexErrorString(input int err, input string re);
import "DPI-C" function int     svlib_dpi_imported_regexRun(input  string re,
                                               input  string str,
                                               input  int    options,
                                               input  int    startPos,
                                               output int    matchCount,
                                               output int    matchList[]);

import "DPI-C" function int     svlib_dpi_imported_getcwd      (output string result);

import "DPI-C" function int     svlib_dpi_imported_getenv(
                                               input  string envVar,
                                               output string result);
import "DPI-C" function int     svlib_dpi_imported_globStart   (input  string pattern,
                                                   output chandle hnd,
                                                   output int     count);
import "DPI-C" function int     svlib_dpi_imported_fileStat    (input  string  path,
                                                   input  int     asLink,
                                                   output longint stats[statARRAYSIZE]);
import "DPI-C" function void    svlib_dpi_imported_hiResTime   (input  int     getResolution,
                                                   output longint seconds,
                                                   output longint nanoseconds);
import "DPI-C" function int     svlib_dpi_imported_timeFormat  (input  longint epochSeconds,
                                                   input  string  format,
                                                   output string  formatted);
import "DPI-C" function int     svlib_dpi_imported_localTime   (input  longint epochSeconds,
                                                   output int     timeItems[tmARRAYSIZE]);
import "DPI-C" function int     svlib_dpi_imported_timeFormatST(input  longint epochSeconds,
                                                   output string  formatted);
                                                   
import "DPI-C" function int     svlib_dpi_imported_access(
                                              input string path,
                                              input int mode,
                                              output int ok);
  
import "DPI-C" context function chandle svlib_dpi_imported_getVlogInfo(output string product, output string version);
import "DPI-C"         function string  svlib_dpi_imported_getVlogInfoNext(inout chandle hnd);
