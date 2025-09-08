package ui

import "core:fmt"
import "../basic/mem"

@(thread_local)
global_tree: ^Tree

// Tree //////////////////////////////////////////////////////////////////////////////

Tree :: struct
{
  data:  []Node,
  cap:   int,
  count: int,
  root:  ^Node,
  curr:  ^Node,
  cache: Cache,
  arena: ^mem.Arena,
}

tree_init :: proc(tree: ^Tree, cap: int, arena: ^mem.Arena)
{
  tree.data = make([]Node, cap, mem.allocator(arena))
  tree.cap = cap
  tree.arena = arena
  tree.root = tree_alloc(tree)
  tree.curr = tree.root
}

@(require_results)
tree_alloc :: proc(tree: ^Tree) -> ^Node
{
  assert(tree.count < tree.cap)
  
  result := &tree.data[tree.count]
  tree.count += 1

  if tree.curr != nil
  {
    result.parent = tree.curr
    node_push_child(tree.curr, result)
  }

  return result
}

tree_clear :: proc(tree: ^Tree)
{
  for &node in tree.data[:]
  {
    node = {}
  }

  tree.count = 1
}

tree_resolve_layout :: proc(tree: ^Tree)
{
  scratch := mem.temp_begin(mem.scratch())
  defer mem.temp_end(scratch)

  // - Standalone sizes ---
  {

  }

  // - Upward sizes ---
  {

  }

  // - Downward sizes ---
  {

  }

  // - Relative positions ---
  {

  }
}

tree_print_bfs :: proc(tree: ^Tree)
{
  scratch := mem.temp_begin(mem.scratch())
  defer mem.temp_end(scratch)

  nodes: [dynamic]^Node
  nodes.allocator = mem.allocator(scratch.arena)
  append(&nodes, tree.root)

  for i := 0; i < len(nodes); i += 1
  {
    node := nodes[i]
    fmt.println(node.name)

    for curr := node.first; curr != nil; curr = curr.next
    {
      append(&nodes, curr)
    }
  }
}

tree_print_dfs :: proc(tree: ^Tree, way: enum{Preorder, Postorder})
{
  scratch := mem.temp_begin(mem.scratch())
  defer mem.temp_end(scratch)

  switch way
  {
  case .Preorder:
    nodes: [dynamic]^Node
    nodes.allocator = mem.allocator(scratch.arena)

    append(&nodes, tree.root)
    for i := len(nodes)-1; i >= 0; i -= 1
    {
      node := pop(&nodes)
      fmt.println(node.name)

      for curr := node.first; curr != nil; curr = curr.next
      {
        append(&nodes, curr)
        i += 1
      }
    }

  case .Postorder:
    Wrapper :: struct{node: ^Node, children_visited: bool}
    nodes: [dynamic]Wrapper
    nodes.allocator = mem.allocator(scratch.arena)

    append(&nodes, Wrapper{tree.root, false})
    for i := len(nodes)-1; i >= 0; i -= 1
    {
      wrap := pop(&nodes)
      if wrap.children_visited || !node_has_children(wrap.node)
      {
        fmt.println(wrap.node.name)
      }
      else
      {
        append(&nodes, Wrapper{wrap.node, true})
        i += 1

        for curr := wrap.node.last; curr != nil; curr = curr.prev
        {
          append(&nodes, Wrapper{curr, false})
          i += 1
        }
      }
    }
  }
}

// Node //////////////////////////////////////////////////////////////////////////////

Node :: struct
{
  parent: ^Node,
  first:  ^Node,
  last:   ^Node,
  next:   ^Node,
  prev:   ^Node,

  name:   string,
  props:  bit_set[Node_Prop],
  offset: [2]f32,
  size:   [2]Size,
  color:  [4]f32,
  text:   string,

  computed_rel_pos: [2]f32,
  computed_abs_dim: [2]f32,

  rect_pos: [2]f32, // persist
  rect_dim: [2]f32, // persist
}

Node_Prop :: enum
{
  Clickable,
  Hoverable,
}

Size :: struct
{
  kind:  Size_Kind,
  value: f32,
}

Size_Kind :: enum
{
  Pixels,
  Percent,
  Child_Sum,
}

current_node :: proc() -> ^Node
{
  return global_tree.curr
}

@(private)
node_has_children :: proc(node: ^Node) -> bool
{
  return node.first != nil
}

@(private)
node_get_child_at :: proc(node: ^Node, idx: int) -> (child: ^Node)
{
  pos: int
  for curr := node.first; curr != nil; curr = curr.next
  {
    child = curr
    if pos == idx do break
    pos += 1
  }

  return
}

@(private)
node_push_child :: proc(node, child: ^Node)
{
  if node.first == nil
  {
    node.first = child
    node.last = child
  }
  else
  {
    curr_last := node.last
    curr_last.next = child
    node.last = child
    node.last.prev = curr_last
  }
}

@(private)
node_pop_child :: proc(node: ^Node) -> ^Node
{
  popped: ^Node

  if node.first != nil
  {
    if node.first == node.last
    {
      popped = node.first
      node.first = nil
      node.last = nil
    }
    else
    {
      prev := node.last.prev
      node.last = prev
      node.last.next = nil
    }
  }

  return popped
}

@(private)
node_remove_child_at :: proc(node: ^Node, idx: int) -> (child: ^Node)
{
  child = node_get_child_at(node, idx)
  if child != nil
  {
    if node.first == node.last
    {
      node.first = nil
      node.last = nil
    }
    else if child == node.first
    {
      node.first.next.prev = nil
      node.first = child.next
    }
    else if child == node.last
    {
      node.last.prev.next = nil
      node.last = child.prev
    }
    else
    {
      node.first.next.prev = nil
      node.last.prev.next = nil
    }
  }
  
  return
}

@(private)
node_print_children :: proc(node: ^Node, way: enum{FWD, BWD})
{
  switch way
  {
  case .FWD:
    for curr := node.first; curr != nil; curr = curr.next
    {
      fmt.println(curr.name)
    }
  
  case .BWD:
    for curr := node.last; curr != nil; curr = curr.prev
    {
      fmt.println(curr.name)
    }
  }
}

test :: proc()
{
  root: Node
  children: [4]Node = {{name="0"}, {name="1"}, {name="2"}, {name="3"}}
  node_push_child(&root, &children[0])
  node_remove_child_at(&root, 1)

  node_print_children(&root, .FWD)
  fmt.println("---")
  node_print_children(&root, .BWD)
}

// Cache ///////////////////////////////////////////////////////////////////////////////

Cache :: struct
{
  data: []^Node,
}

cache_lookup :: proc()
{

}

// Layout //////////////////////////////////////////////////////////////////////////////

begin_layout :: proc(tree: ^Tree)
{
  tree_clear(tree)
  tree.root.name = "root"
  global_tree = tree
}

end_layout :: proc()
{
  tree_resolve_layout(global_tree)
  global_tree = nil
}

@(deferred_none=end_box, require_results)
box :: proc(name: string = "") -> bool
{
  tree := global_tree

  node := tree_alloc(tree)
  node.name = (name != "") ? name : "unnamed"
  node.parent = tree.curr
  
  tree.curr = node

  return true
}

end_box :: proc()
{
  global_tree.curr = global_tree.curr.parent
}

layout_size_x :: proc(kind: Size_Kind, val: f32)
{
  global_tree.curr.size.x = Size{kind, val}
}

layout_size_y :: proc(kind: Size_Kind, val: f32)
{
  global_tree.curr.size.y = Size{kind, val}
}

layout_offset :: proc(off: [2]f32)
{
  global_tree.curr.offset = off
}

layout_fill_color :: proc(color: [4]f32)
{
  global_tree.curr.color = color
}

layout_tint_color :: proc(color: [4]f32) {}
