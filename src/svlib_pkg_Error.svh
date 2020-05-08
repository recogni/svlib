//=============================================================================
//  @brief  error handling functions
//  @author Jonathan Bromley, Verilab (www.verilab.com)
//=============================================================================
//
//                      svlib SystemVerilog Utilities Library
//
// @File: svlib_pkg_Error.svh
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
// Function definitions that are not part of classes

// error_getManager ===========================================================
// Get a reference to the singleton errorManager object.
// User code won't normally need this, but it's provided
// to allow for future extensions.
function automatic svlibErrorManager error_getManager();
  return svlibErrorManager::getInstance();
endfunction: error_getManager

// error_userHandling =========================================================
// Set user error handling.
// If setDefault is false or not supplied, the ~user~ bit specifies
// whether future svlib errors in the current process will be handled
// automatically by an assertion (0), or should be handled by the user (1).
// If setDefault is true, the ~user~ bit specifies the default value
// of userHandling for processes created in the future - it does NOT
// change the userHandling setting for the current process.
function automatic void error_userHandling(bit user, bit setDefault=0);
  svlibErrorManager errorManager = error_getManager();
  errorManager.setUserHandling(user, setDefault);
endfunction: error_userHandling

// error_getLast ==============================================================
// Get the most recent error. Optionally, mark it as cleared
// in the error tracker. Clearing the error does NOT destroy
// the last-error and detailed error text until another
// error occurs.
function automatic int error_getLast(bit clear = 1);
  svlibErrorManager errorManager = error_getManager();
  return errorManager.getLast(clear);
endfunction: error_getLast

// error_test =================================================================
// Get the string corresponding to a specific svlib error number.
// If err=0, get the error string for the most recent error,
// without clearing it.
function automatic string error_text(int err=0);
  svlibErrorManager errorManager = error_getManager();
  return errorManager.getText(err);
endfunction: error_text

// error_details ==============================================================
// Get user-supplied details for the most recent error,
// without clearing it.
function automatic string error_details();
  svlibErrorManager errorManager = error_getManager();
  return errorManager.getDetails();
endfunction: error_details

// error_fullMessage ==========================================================
// Get a consistent, complete error message for the
// most recent error, without clearing it. The message
// is in the same format as used by svlib's built-in 
// assertions.
function automatic string error_fullMessage();
  svlibErrorManager errorManager = error_getManager();
  return errorManager.getFullMessage();
endfunction: error_fullMessage

// error_debugReport ==========================================================
// Debug reporting.
function automatic qs error_debugReport();
  svlibErrorManager errorManager = error_getManager();
  return errorManager.report();
endfunction: error_debugReport
