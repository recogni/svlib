//=============================================================================
//  @brief  Implementations (bodies) of extern functions for cfgScalar classes
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

//=============================================================================
// Concrete class definitions extended from cfgScalar via cfgTypedScalar
//=============================================================================


//-----------------------------------------------------------------------------
// class cfgScalarInt extends cfgTypedScalar#(logic signed [63:0]);

function string cfgScalarInt::str();
  if (!$isunknown(value)) begin
    return $sformatf("%0d", value);
  end
  else if (value < 0) begin
    // Has X/Z but is known to be -ve
    return $sformatf("-'h%0h", -value);
  end
  else begin
    // Has X/Z but is not -ve
    return $sformatf("'h%0h", value);
  end
endfunction: str

function bit cfgScalarInt::scan(string s);
  return scanVerilogInt(s, value);
endfunction

function cfgObjKind_enum  cfgScalarInt::kind();
  return SCALAR_INT;
endfunction: kind

function cfgScalarInt cfgScalarInt::create(T v = 0);
  create = Obstack#(cfgScalarInt)::obtain();
  create.name = "";
  create.value = v;
endfunction: create

function cfgNodeScalar cfgScalarInt::createNode(string name, T v = 0);
  cfgNodeScalar ns = cfgNodeScalar::create(name);
  ns.value = cfgScalarInt::create(v);
  return ns;
endfunction: createNode

//-----------------------------------------------------------------------------
// class cfgScalarString extends cfgTypedScalar#(string);

function string cfgScalarString::str();
  return get();
endfunction:str

function bit cfgScalarString::scan(string s);
  set(s);
  return 1;
endfunction: scan

function cfgObjKind_enum cfgScalarString::kind();
 return SCALAR_STRING;
endfunction: kind

function cfgScalarString cfgScalarString::create(string v = "");
  create = Obstack#(cfgScalarString)::obtain();
  create.name = "";
  create.value = v;
endfunction: create

function cfgNodeScalar cfgScalarString::createNode(string name, string v = "");
  cfgNodeScalar ns = cfgNodeScalar::create(name);
  ns.value = cfgScalarString::create(v);
  return ns;
endfunction: createNode

