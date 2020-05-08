//=============================================================================
//  @brief  Implementations (bodies) of extern functions for cfgBase
//  @author Jonathan Bromley, Verilab (www.verilab.com)
//=============================================================================
//
//                      svlib SystemVerilog Utilities Library
//
// @File: svlib_impl_Cfg.svh
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

// svlibCfgBase

function string svlibCfgBase::getName();
  return name;
endfunction: getName

function string svlibCfgBase::getLastErrorDetails();
  return lastErrorDetails;
endfunction: getLastErrorDetails

function cfgError_enum svlibCfgBase::getLastError();
  return lastError;
endfunction: getLastError

function string svlibCfgBase::kindStr();
  cfgObjKind_enum k = kind();
  return k.name;
endfunction: kindStr

//-----------------------------------------------------------------------------
// Protected methods

function void svlibCfgBase::purge();
  name = "";
  lastError = CFG_OK;
  lastErrorDetails = "";
endfunction: purge

function void svlibCfgBase::cfgObjError(cfgError_enum err);
  if (err == CFG_OK) return;
  // There was an error. Set up the error information:
  lastError = err;
  lastErrorDetails = errorDetails(err);
  // and throw the (optional) assertion error
  cfgNode_check_validity :
    assert (err == CFG_OK) else
      $error("%s \"%s\": %s",
       kindStr(), name, lastErrorDetails);
endfunction: cfgObjError

function string svlibCfgBase::errorDetails(cfgError_enum err);
  return $sformatf("operation failed because %s", err.name);
endfunction: errorDetails

