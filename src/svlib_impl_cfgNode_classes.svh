//=============================================================================
//  @brief  Implementations (bodies) of extern functions for cfgNode classes
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

// class cfgNode extends cfgNode;

function void cfgNode::purge();
  super.purge();
  comments.delete();
  serializationHint = "";
  parent = null;
endfunction: purge

function void cfgNode::addNode(cfgNode nd);
  cfgObjError(CFG_ADDNODE_CANNOT_ADD);
endfunction: addNode

function cfgNode cfgNode::getFoundNode();
  return foundNode;
endfunction: getFoundNode

function string cfgNode::getFoundPath();
  return foundPath;
endfunction: getFoundPath

function cfgNode cfgNode::getParent();
  return parent;
endfunction: getParent

function cfgNode cfgNode::lookup(string path);
  int nextPos;
  Regex re = Obstack#(Regex)::obtain();
  re.setStrContents(path);
  re.setRE(
  //   1: first path component, complete with leading/trailing whitespace
  //   |    2: first path component, with leading/trailing whitespace trimmed
  //   |    |       3: digits of index, trimmed, if index exists
  //   |    |       |                     4: relative-path '.' if it exists
  //   |    |       |                     |         5: name key, trimmed, if it exists
  //   |    |       |                     |         |               6: tail of name key (ignore this)
  //   |    |       |                     |         |               |                                7: tail
  //   1----2=======3************3========4***4=====5***************6#######################6*52----17--7
     "^(\\s*(\\[\\s*([[:digit:]]+)\\s*\\]|(\\.)?\\s*([^].[[:space:]]([^].[]*[^].[[:space:]]+)*))\\s*)(.*)$");

  nextPos = 0;
  foundNode = this;
  forever begin
    bit isIdx, isRel;
    string idx;
    cfgNode node;
    if (!re.retest(nextPos)) begin
      lastError = CFG_LOOKUP_BAD_SYNTAX;
      break;
    end
    isIdx = (re.getMatchStart(3) >= 0);
    isRel = isIdx || (re.getMatchStart(4) >= 0);
    if (!isRel && (nextPos > 0)) begin
      lastError = CFG_LOOKUP_MISSING_DOT;
      break;
    end
    if (foundNode == null) begin
      lastError = CFG_LOOKUP_NULL_NODE;
      break;
    end
    if (isIdx) begin
      if (foundNode.kind() != NODE_SEQUENCE) begin
        lastError = CFG_LOOKUP_NOT_SEQUENCE;
        break;
      end
      idx = re.getMatchString(3);
    end
    else begin
      if (foundNode.kind() != NODE_MAP) begin
        lastError = CFG_LOOKUP_NOT_MAP;
        break;
      end
      idx = re.getMatchString(5);
    end
    foundNode = foundNode.childByName(idx);
    if (foundNode == null) begin
      lastError = CFG_LOOKUP_NOT_FOUND;
      break;
    end
    nextPos = re.getMatchStart(7);
    if (nextPos == path.len()) begin
      lastError = CFG_OK;
      break;
    end
  end
  Obstack#(Regex)::relinquish(re);
  foundPath = path.substr(0,nextPos-1);
  return (lastError == CFG_OK) ? foundNode : null;
endfunction

//-----------------------------------------------------------------------------

// class cfgNodeScalar extends cfgNode;

function void cfgNodeScalar::purge();
  super.purge();
  value = null;
endfunction: purge

function string cfgNodeScalar::sformat(int indent = 0);
  return $sformatf("%s%s", str_repeat(" ", indent), value.str());
endfunction: sformat


function cfgObjKind_enum cfgNodeScalar::kind();
  return NODE_SCALAR;
endfunction: kind

function cfgNode cfgNodeScalar::childByName(string idx);
  return null;
endfunction: childByName

//-----------------------------------------------------------------------------

// class cfgNodeSequence extends cfgNode;

function void cfgNodeSequence::purge();
  super.purge();
  value.delete();
endfunction: purge

function string cfgNodeSequence::sformat(int indent = 0);
  foreach (value[i]) begin
    if (i != 0) sformat = {sformat, "\n"};
    sformat = {sformat, str_repeat(" ", indent), "- \n", value[i].sformat(indent+1)};
  end
endfunction: sformat

function cfgObjKind_enum cfgNodeSequence::kind();
  return NODE_SEQUENCE;
endfunction: kind

function void cfgNodeSequence::addNode(cfgNode nd);
  if (nd == null) begin
    cfgObjError(CFG_ADDNODE_NULL);
    return;
  end
  nd.parent = this;
  value.push_back(nd);
  cfgObjError(CFG_OK);
endfunction: addNode

function cfgNode cfgNodeSequence::childByName(string idx);
  int n = idx.atoi();
  if (n >= value.size() || n<0)
    return null;
  else
    return value[n];
endfunction: childByName

//-----------------------------------------------------------------------------

// class cfgNodeMap extends cfgNode;

function void cfgNodeMap::purge();
  super.purge();
  value.delete();
endfunction: purge

function string cfgNodeMap::sformat(int indent = 0);
  bit first = 1;
  foreach (value[s]) begin
    if (first)
      first = 0;
    else
      sformat = {sformat, "\n"};
    sformat = {sformat, str_repeat(" ", indent), s, " : \n", value[s].sformat(indent+1)};
  end
endfunction: sformat

function cfgObjKind_enum cfgNodeMap::kind();
  return NODE_MAP;
endfunction: kind

function void cfgNodeMap::addNode(cfgNode nd);
  if (nd == null) begin
    cfgObjError(CFG_ADDNODE_NULL);
    return;
  end
  if (value.exists(nd.getName())) begin
    cfgObjError(CFG_ADDNODE_DUPLICATE_KEY);
  end
  nd.parent = this;
  value[nd.getName()] = nd;
  cfgObjError(CFG_OK);
endfunction: addNode

function cfgNode cfgNodeMap::childByName(string idx);
  if (!value.exists(idx))
    return null;
  else
    return value[idx];
endfunction: childByName
