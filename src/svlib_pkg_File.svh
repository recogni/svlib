//=============================================================================
//  @brief  class and methods for pathnames
//  @author Jonathan Bromley, Verilab (www.verilab.com)
//=============================================================================
//
//                      svlib SystemVerilog Utilities Library
//
// @File: svlib_pkg_File.svh
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

class Pathname extends svlibBase;

  //---------------------------------------------------------------------------
  // Protected functions and members

  // forbid construction
  protected function new(); 
            endfunction: new

  extern protected virtual function void   purge();
  extern protected virtual function string render(int first, int last);

  protected qs  comps;
  protected bit absolute;
  static protected Str separator = Str::create("/");

  //---------------------------------------------------------------------------

  extern static function Pathname create(string s = "");

  extern virtual function string   get           ();
  extern virtual function bit      isAbsolute    ();
  extern virtual function string   dirname       (int backsteps=1);
  extern virtual function string   extension     ();
  extern virtual function string   basename      ();
  extern virtual function string   tail          (int backsteps=1);
  extern virtual function string   volume        ();  // always '/' on *nix
  
  extern virtual function Pathname copy          ();
  extern virtual function void     set           (string path);
  extern virtual function void     append        (string tail);
  extern virtual function void     appendPN      (Pathname tailPN);
  
endclass: Pathname

//=============================================================================
// Function definitions that are not class-based


// file_mTime =================================================================
function automatic longint file_mTime(string path, bit asLink=0);
  sys_fileStat_s stat = sys_fileStat(path, asLink);
  return stat.mtime;
endfunction: file_mTime

// file_aTime =================================================================
function automatic longint file_aTime(string path, bit asLink=0);
  sys_fileStat_s stat = sys_fileStat(path, asLink);
  return stat.atime;
endfunction: file_aTime

// file_cTime =================================================================
function automatic longint file_cTime(string path, bit asLink=0);
  sys_fileStat_s stat = sys_fileStat(path, asLink);
  return stat.ctime;
endfunction: file_cTime

// file_size ==================================================================
function automatic longint file_size(string path, bit asLink=0);
  sys_fileStat_s stat = sys_fileStat(path, asLink);
  return stat.size;
endfunction: file_size

// file_mode ==================================================================
function automatic sys_fileMode_s file_mode(string path, bit asLink=0);
  sys_fileStat_s stat = sys_fileStat(path, asLink);
  return stat.mode;
endfunction: file_mode

// file_accessible ============================================================
function automatic bit file_accessible(string path, sys_fileRWX_s mode = 0);
  int ok;
  svlibErrorManager errorManager = error_getManager();
  int err = svlib_dpi_imported_access(path, mode, ok);
  if (err) begin
    qs modes;
    ACCESS_MODE_ENUM all_modes[$];
    all_modes = EnumUtils#(ACCESS_MODE_ENUM)::allValues();
    foreach(all_modes[i]) begin
      if (mode & all_modes[i]) begin
        modes.push_back(all_modes[i].name);
      end
    end
    // special case for the oddball, known to be zero
    if (modes.size()==0) begin
      modes.push_back("accessEXISTS");
    end
    errorManager.submit(err, 
      $sformatf("file_accessible(%s, %s) failed", path, str_sjoin(modes, " | ")));
  end
  else begin
    errorManager.submit(0);
  end

  return ok;
endfunction: file_accessible

//============================================================================
/////////////////// IMPLEMENTATIONS OF EXTERN CLASS METHODS ///////////////////

`include "svlib_impl_File.svh"
