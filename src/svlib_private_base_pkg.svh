//=============================================================================
//  @brief  Private collection of functionality used in svlib Do Not Import!
//  @author Jonathan Bromley, Verilab (www.verilab.com)
//=============================================================================
//
//                      svlib SystemVerilog Utilities Library
//
// @File: svlib_private_base_pkg.svh
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
// 
// This file defines svlib_private_base_pkg, a collection of
// functionality that is required by other parts of svLib.
// It also imports all the DPI functions that are required by
// other parts of the package.
//=============================================================================
//
//=============================================================================
//                       IMPORTANT NOTE
//=============================================================================
// USER CODE SHOULD *NOT* IMPORT THIS PACKAGE. In this way,
// user code does not have access directly to the DPI functions,
// allowing svLib to take full control of the SV/C interaction.
//=============================================================================

package svlib_private_base_pkg;

  `include "svlib_dpi_imports.svh"

  // Queue-of-strings is needed very widely in the library code,
  // so we create a convenient typedef for it here.
  typedef string qs[$];


  // Consistent mechanism to recover a queue of strings, of unknown length,
  // from data that's been set up on the DPI-C side. ~hnd~ is the C pointer,
  // supplied by some earlier DPI call, referencing the C string array data.
  // This function repeatedly calls svlib_dpi_imported_saBufNext to retrieve
  // one string from the C array and bump the handle variable on to the next.
  //   ~keep_ss~ set: function appends to existing contents of ss.
  // ~keep_ss~ clear: function deletes existing contents of ss before starting.
  //
  function automatic int svlib_private_getQS(input chandle hnd, ref qs ss, input bit keep_ss=0);
    int result;
    string s;
    if (!keep_ss)    ss.delete();
    if (hnd == null) return 0;
    forever begin
      result = svlib_dpi_imported_saBufNext(hnd, s);
      if (result != 0) return result;
      if (hnd == null) return 0;
      ss.push_back(s);
    end
  endfunction
  
  
  // Mystery problem: Trying to call process::self() from a static
  // method of Obstack#(T) crashes the compiler in VCS 2013.06.
  // Providing this function seems to work around the problem OK.
  function automatic process get_running_process();
    return process::self();
  endfunction


  // Obstack needs to extend T so that it can do new()
  // even if T's constructor is protected.
  class Obstack #(parameter type T=int) extends T;
    local static T   stack[$];
    local static int constructed_ = 0;
    local static int get_calls_ = 0;
    local static int put_calls_ = 0;

    // forbid construction
    protected function new(); endfunction

    static function T obtain();
      T result;
      if (stack.size()==0) begin
        `ifdef SVLIB_NO_RANDSTABLE_NEW
        result = new();
        `else
        process p = get_running_process();
        ast_obtain_from_valid_process:
          assert (p != null) else
            $warning("svlib object created from null process");
        if (p == null) begin
          result = new();
        end
        else begin
          string randstate = p.get_randstate();
          result = new();
          p.set_randstate(randstate);
        end
        `endif
        constructed_++;
      end
      else begin
        result = stack.pop_back();
        result.purge();
      end
      get_calls_++;
      return result;
    endfunction

    static function void relinquish(T t);
      put_calls_++;
      if (t == null) return;
      stack.push_back(t);
    endfunction

    // debug/test only - DO NOT USE normally
    static function void stats(
        output int depth,
        output int constructed,
        output int get_calls,
        output int put_calls
      );
      depth = stack.size();
      constructed = constructed_;
      get_calls = get_calls_;
      put_calls = put_calls_;
    endfunction

  endclass

  // svlibBase: base class for almost all svlib classes.
  //
  virtual class svlibBase;
    // purge() wipes any content from the existing object,
    // restoring it to the same pristine state as a new object
    pure virtual protected function void purge();
  endclass

  // svlibErrorManager: singleton class to handle
  // per-process error management. A single instance
  // is stored as a static variable and can be returned
  // by the static getInstance method.
  //
  class svlibErrorManager extends svlibBase;

    `ifdef XCELIUM
      typedef string INDEX_T;
      protected function INDEX_T indexFromProcess(process p);
        return $sformatf("%p", p);
      endfunction
    `else
      typedef process INDEX_T;
      protected function INDEX_T indexFromProcess(process p);
        return p;
      endfunction
    `endif

    // forbid construction
    protected function new(); 
              endfunction

    protected int    valuePerProcess   [INDEX_T];
    protected bit    pendingPerProcess [INDEX_T];
    protected bit    userPerProcess    [INDEX_T];
    protected string detailsPerProcess [INDEX_T];
    protected bit    defaultUserBit;

    protected function void purge();
      valuePerProcess.delete();
      pendingPerProcess.delete();
      userPerProcess.delete();
      detailsPerProcess.delete();
      defaultUserBit = 0;
    endfunction
    
    protected function INDEX_T getIndex();
      return indexFromProcess(process::self());
    endfunction

    static svlibErrorManager singleton = null;
    static function svlibErrorManager getInstance();
      if (singleton == null) begin
        singleton = Obstack#(svlibErrorManager)::obtain();
      end
      return singleton;
    endfunction

    protected virtual function bit has(INDEX_T idx);
      return valuePerProcess.exists(idx);
    endfunction

    protected virtual function void update(INDEX_T idx, int value, string details = "");
      pendingPerProcess [idx] = (value != 0);
      valuePerProcess   [idx] = value;
      detailsPerProcess [idx] = details;
    endfunction

    protected virtual function void newIndex(INDEX_T idx, int value, string details = "");
      userPerProcess [idx] = defaultUserBit;
      update(idx, value, details);
    endfunction

    virtual function void submit(int err, string details = "");
      INDEX_T idx = getIndex();
      if (!has(idx)) begin
        newIndex(idx, err, details);
      end
      svlibBase_check_unhandledError: assert (!pendingPerProcess[idx]) else
        $error("Previous error not yet handled before next errorable call:\n  %s",
                          getFullMessage()
        );
      update(idx, err, details);
      if (!userPerProcess[idx]) begin
        pendingPerProcess[idx] = 0;
        assert (err == 0) else
          $error(getFullMessage());
      end
    endfunction

    virtual function int getLast(bit clear = 1);
      INDEX_T idx = getIndex();
      if (has(idx)) begin
        if (clear)
          pendingPerProcess[idx] = 0;
        return valuePerProcess[idx];
      end
      else begin
        return 0;
      end
    endfunction

    virtual function bit getUserHandling(bit getDefault=0);
      if (getDefault) begin
        return defaultUserBit;
      end else begin
        INDEX_T idx = getIndex();
        if (!has(idx))
          return defaultUserBit;
        else
          return userPerProcess[idx];
      end
    endfunction

    virtual function void setUserHandling(bit user, bit setDefault=0);
      if (setDefault) begin
        defaultUserBit = user;
      end
      else begin
        INDEX_T idx = getIndex();
        if (!has(idx)) begin
          newIndex(idx, 0);
        end
        userPerProcess[idx] = user;
      end
    endfunction

    virtual function qs report();
      report.push_back($sformatf("----\\/---- Per-Process Error Manager ----\\/----"));
      report.push_back($sformatf("  Default user-mode = %b", defaultUserBit));
      if (userPerProcess.num) begin
        report.push_back($sformatf("  user pend details"));
        foreach (userPerProcess[idx]) begin
          report.push_back($sformatf("    %b    %b  %s",
                         userPerProcess[idx],
                            pendingPerProcess[idx],
                                fullMessageByIndex(idx)));
        end
      end
      report.push_back($sformatf("----/\\---- Per-Process Error Manager ----/\\----"));
    endfunction

    // Get the string corresponding to a specific C error number.
    // If err=0, use the most recent error instead.
    virtual function string getText(int err=0);
      if (err==0) begin
        // Find the last error without clearing it
        err = getLast(0);
      end
      return svlib_dpi_imported_getCErrStr(err);
    endfunction

    // Set/get a programmer-supplied string for context information
    virtual function void setDetails(string details);
      INDEX_T idx = getIndex();
      if (!has(idx)) begin
        newIndex(idx, 0);
      end
      detailsPerProcess[idx] = details;
    endfunction
    virtual function string getDetails();
      INDEX_T idx = getIndex();
      if (has(idx)) begin
        return detailsPerProcess[idx];
      end
      else begin
        return "";
      end
    endfunction
    
    protected virtual function string fullMessageByIndex(INDEX_T idx);
      return $sformatf("%s (errno=%0d): %s", 
               getText(valuePerProcess[idx]), 
                 valuePerProcess[idx], 
                   detailsPerProcess[idx]);
    endfunction
    
    virtual function string getFullMessage();
      INDEX_T idx = getIndex();
      if (has(idx)) begin
        return fullMessageByIndex(idx);
      end
      else begin
        return "Unknown process";
      end
    endfunction
    
  endclass

  //===========================================================================
  // function scanUint64: not for public API! Assumes that the 
  // radix letter is OK, and the value-string has been stripped
  // of spaces and is reasonably sane. No handling of -ve numbers.
  // Result is always zero-filled to 64 bits.
  //===========================================================================
  // This function reads from a string representation into a 64-bit value.
  // X/Z values are supported. Underscores are ignored. Otherwise, illegal
  // digits cause an error (0) to be returned and the result is undefined.
  // Unfortunately, sscanf can't be used because it doesn't tell us when 
  // it stopped, so we can't detect bad characters.
  // We already know that the characters are sure to be underscores,
  // hex digits, or X/Z. Leading and trailing underscores have already
  // been removed by the regex that got us here.

  function automatic bit scanUint64(int nBits, bit isSigned, string radixLetter, string v, output logic [63:0] result);
    logic [63:0] value;
    int radix, shift, msb;
    case (radixLetter)
      "h", "H", "x", "X" :
        begin radix= 16; shift = 4; end
      "o", "O" :
        begin radix = 8; shift = 3; end
      "d", "D" , "" :
        begin radix = 10; end // shift is not used
      "b", "B" :
        begin radix = 2; shift = 1; end
      default :
        return 0; // immediate fail
    endcase

    v = v.toupper();

    value = 0;

    if (radix == 10) begin
      // Special treatment for decimal numbers. If there is
      // an X or Z, it must be the one and only digit.
      // Leading and trailing underscores have already been
      // removed, so this test is valid.
      msb = 63;
      if (v == "X") begin
        result = 'x;
        return 1;
      end
      else if (v == "Z") begin
        result = 'z;
        return 1;
      end
      else begin
      
        foreach (v[i]) begin
          if (v[i] == "_") begin
            continue;
          end
          else if (v[i] inside {["0":"9"]}) begin
            value = 10*value + v[i] - "0";
          end
          else begin
            return 0;
          end
        end

      end
    end
    else begin
      // radix is 2/8/16

      msb = -1;
      foreach (v[i]) begin
        logic [3:0] digit;
        if (v[i] == "_") begin
          continue;
        end
        else begin
          msb += shift;
        end
        if (v[i] == "X") begin
          digit = 'x;
        end 
        else if (v[i] == "Z") begin
          digit = 'z;
        end
        else if (v[i] inside {["0":"9"]}) begin
          digit = v[i] - "0";
        end
        else if (v[i] inside {["A":"F"]}) begin
          digit = v[i] - "A" + 10;
        end
        else begin
          return 0;
        end
        if (digit >= radix) begin
          return 0;
        end
        value <<= shift;
        for (int b=0; b<shift; b++) value[b] = digit[b];
      end

    end

    // Protect against too many digits
    if (msb >= nBits) begin
      for (int i=nBits; i<=msb; i++) value[i] = 1'b0;
    end
    // Z/X fill to specified width
    if ($isunknown(value[msb])) begin
      for (int i=msb+1; i<nBits; i++) value[i] = value[msb];
    end
    if (isSigned) begin
      for (int i=nBits; i<64; i++) value[i] = value[nBits-1];
    end
    result = value;
    return 1;

  endfunction

endpackage
