package mem0

import "base:intrinsics"
import "base:runtime"
import "core:mem/virtual"
import "core:mem/tlsf"

Allocator       :: runtime.Allocator
Allocator_Error :: runtime.Allocator_Error
Arena           :: virtual.Arena
Temp      			:: virtual.Arena_Temp
Heap						:: tlsf.Allocator

KIB :: 1 << 10
MIB :: 1 << 20
GIB :: 1 << 30

@(thread_local, private)
global_scratches: [2]Arena

@(init)
init_scratches :: proc()
{
	_ = arena_init_growing(&global_scratches[0])
	_ = arena_init_growing(&global_scratches[1])
}

copy :: #force_inline proc "contextless" (dst, src: rawptr, len: int) -> rawptr
{
	intrinsics.mem_copy(dst, src, len)
	return dst
}

zero :: #force_inline proc "contextless" (data: rawptr, len: int) -> rawptr
{
	intrinsics.mem_zero(data, len)
	return data
}

allocator :: proc
{
	allocator_arena,
	allocator_heap,	
}

allocator_arena :: #force_inline proc "contextless" (arena: ^Arena) -> Allocator
{
	return Allocator{
		procedure = virtual.arena_allocator_proc,
		data = arena,
	}
}

allocator_heap :: #force_inline proc "contextless" (heap: ^Heap) -> Allocator
{
	return Allocator{
		procedure = tlsf.allocator_proc,
		data = heap,
	}
}

// Arena /////////////////////////////////////////////////////////////////////////////////

arena_init_buffer  :: virtual.arena_init_buffer
arena_init_growing :: virtual.arena_init_growing
arena_init_static  :: virtual.arena_init_static
arena_destroy			 :: virtual.arena_destroy

temp_begin :: virtual.arena_temp_begin
temp_end	 :: virtual.arena_temp_end

scratch :: proc(conflict: ^Arena = nil) -> ^Arena
{
	result := &global_scratches[0]

	if conflict == nil do return result

	if cast(uintptr) result.curr_block.base == cast(uintptr) conflict.curr_block.base
	{
		result = &global_scratches[1]
	}

	return result
}

// Heap //////////////////////////////////////////////////////////////////////////////////

heap_init 							 :: tlsf.init
heap_init_from_allocator :: tlsf.init_from_allocator
heap_init_from_buffer 	 :: tlsf.init_from_buffer
heap_destroy						 :: tlsf.destroy
