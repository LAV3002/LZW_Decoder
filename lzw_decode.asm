global lzw_decode

section .text

;EAX: old_code:code, EBX: FREE, ECX: table_size:readed_from_buf:length, EDX: FREE, ESI: in_buf, EDI: out_ptr, EBP: FREE
;[ESP]: in_ptr, [ESP + 4]: out_ptr, [ESP + 8]: in_bound, [ESP + 12]: out_bound

lzw_decode:
	push ebp
	push ebx
	push esi
	push edi
	mov esi, [esp + 20]
	mov ebp, [esp + 24]
	mov edi, [esp + 28]
	mov edx, [esp + 32]
	sub esp, 33040; 4096 * 2 * 4 + 256 + 4 * 4
	mov eax, 8260; 4096 * 2 + 4 + 64
_init_loop:
	mov ebx, [esp + eax * 4]
	dec eax
	cmp eax, 0
	jne _init_loop
	mov ebx, 255
_init_char_table_loop:
	mov [esp + ebx + 16], bl
	dec ebx
	jnz _init_char_table_loop
	mov [esp + 16], bl
_init_stack:
	mov [esp], esi
	add esi, ebp
	mov [esp + 8], esi
	mov [esp + 4], edi
	add edi, edx
	mov [esp + 12], edi
	sub edi, edx
_init_reg:
	mov ecx, 0x10002009
	mov edx, 0x00000000
_main_loop:
	prefetch [esp]
	call _get_code
	cmp ax, 257
	je _ret
	cmp ax, 256
	jne _body
	call _initialize_table
	call _get_code
	cmp ax, 257
	je _ret
	xor ebx, ebx; mozno vipilit
	mov bx, ax
	call _write
	jmp _main_loop
_body:
	mov ebx, ecx
	shr ebx, 16
	cmp ax, bx
	jge _body_land1
	mov ebx, eax
	and ebx, 0x0000ffff
	call _write
	jmp _body_land2
_body_land1:
	mov ebx, eax
	shr ebx, 16
	call _write
	mov ebx, eax
	shr ebx, 16
	call _write_begin
_body_land2:
	call _add_string_to_table
	jmp _main_loop
_ret:
	add esp, 33040
	mov eax, edi
	mov ecx, [esp + 28]
	sub eax, ecx
	pop edi
	pop esi
	pop ebx
	pop ebp
	ret

_get_code: ;EAX: old_code:code, EBX: FREE, ECX: table_size:readed_from_buf:length, EDX: FREE, ESI: in_buf, EDI: out_ptr, EBP: FREE
	;esp -= 4
	mov bl, ch; bl = readed_from_buf
	shl eax, 16; old_code = code
	add bl, cl; bl += length
	cmp bl, 32
	jg _get_code_read
	xor ebx, ebx
	shld ebx, esi, cl
	shl esi, cl
	add ch, cl
	mov ax, bx
	ret
_get_code_read:
	cmp ch, 32
	jne _skip_mov_esi_0
	mov esi, 0
_skip_mov_esi_0:
	mov ebp, [esp + 4]
	mov edx, [esp + 12]
	xchg ch, cl
	shr esi, cl
	xchg ch, cl
	mov ebx, esi
	cmp ebp, edx
	jge .bad_ret
	sub edx, 4
	cmp ebp, edx
	jg _get_code_shift
	movbe esi, [ebp]
	add ebp, 4; buf = uint8
	mov [esp + 4], ebp
	mov edx, 32
	sub dl, ch; dl - 
	sub cl, dl
	shld ebx, esi, cl
	shl esi, cl
	mov ch, cl
	add cl, dl
	mov ax, bx
	ret
.bad_ret:
	mov eax, -1
	ret
_get_code_shift:
	push ecx
	sub ebp, edx
	shl ebp, 3
	mov ecx, ebp
	movbe esi, [edx]
	shl esi, cl
	pop ecx
	add edx, 4; buf = uint8
	mov [esp + 4], edx
	mov edx, 32
	sub dl, ch; dl - 
	sub cl, dl
	shld ebx, esi, cl
	shl esi, cl
	mov ch, cl
	add cl, dl
	mov edx, ebp;;whaat
	add ch, dl
	mov ax, bx
	ret	

_write: ;EAX: old_code:code, EBX: FREE, ECX: table_size:readed_from_buf:length, EDX: FREE, ESI: in_buf, EDI: out_ptr, EBP: FREE
	call _write_string
	ret

_write_char: ;EAX: old_code:code, EBX: FREE, ECX: table_size:readed_from_buf:length, EDX: FREE, ESI: in_buf, EDI: out_ptr, EBP: FREE
;esp -= 8
	mov edx, [esp + 20]
	cmp edx, edi
	je .bad_ret
	mov [edi], bl
	add edi, 1; buf = uint8
	mov ebp, 1
	ret
.bad_ret:
	mov eax, -1
	ret

_write_string: ;EAX: old_code:code, EBX: FREE, ECX: table_size:readed_from_buf:length, EDX: FREE, ESI: in_buf, EDI: out_ptr, EBP: FREE
;esp -= 8
	mov edx, [esp + ebx * 4 + 16408 + 256];EBX: size_to_write
	mov ebx, [esp + ebx * 4 + 24 + 256];EBX: adress_to_write
	mov ebp, [esp + 20]
	sub ebp, 10
	sub ebp, edx
	cmp ebp, edi
	jle _1_byte_mode
_write_string_loop:
	mov ebp, [ebx]
	mov [edi], ebp
	add edi, 4
	add ebx, 4
	sub dx, 4
	add edx, 0x00040000
	cmp dx, 0
	jg _write_string_loop
	mov ebx, edx
	shr ebx, 16
	xor ebp, ebp
	sub bp, dx
	sub edi, ebp
	sub ebx, ebp
	mov ebp, ebx
	ret
_1_byte_mode:
	push edx
	mov edx, [esp + 24]
	cmp edx, edi
	je .bad_ret
	pop edx
	push eax
	mov al, [ebx]
	mov [edi], al
	pop eax
	add edi, 1
	add ebx, 1
	sub dx, 1
	add edx, 0x00010000
	cmp dx, 0
	jg _1_byte_mode
	mov ebx, edx
	shr ebx, 16
	xor ebp, ebp
	sub bp, dx
	sub edi, ebp
	sub ebx, ebp
	mov ebp, ebx
	ret
.bad_ret:
	pop edx
	mov eax, -1
	ret


_write_begin: ;EAX: old_code:code, EDI: out -> EBP: count of writed bytes
	mov edx, [esp + 16]
	cmp edx, edi
	je .bad_ret
	mov ebx, [esp + ebx * 4 + 20 + 256];EBX: adress_to_write
	mov ebx, [ebx]
	mov [edi], bl
	inc edi
	add ebp, 1
	ret
.bad_ret:
	mov eax, -1
	ret


_initialize_table: ;EAX: old_code:code, EBX: FREE, ECX: table_size:readed_from_buf:length, EDX: FREE, ESI: in_buf, EDI: out_ptr, EBP: FREE
	movdqu  xmm0, [const_zeros]
	mov ebx, 1023
	shl ebx, 4
.loop1:
	movdqu [esp + ebx + 16404 + 256], xmm0; 4 + 4 * 4 + 4096 * 4
	sub ebx, 16
	jnz .loop1
	movdqu [esp + 16404 + 256], xmm0; 4 + 4 * 4 + 4096 * 4
	movdqu  xmm0, [const_ones]
	mov ebx, 63
	shl ebx, 4
.loop2:
	movdqu [esp + ebx + 16404 + 256], xmm0; 4 + 4 * 4 + 4096 * 4
	sub ebx, 16
	jnz .loop2
	movdqu [esp + 16404 + 256], xmm0; 4 + 4 * 4 + 4096 * 4
	mov ebx, 255
	mov edx, 255
	add edx, esp
	add edx, 20
.loop3:
	mov [esp + ebx * 4 + 20 + 256], edx
	dec edx
	dec ebx
	jnz .loop3;
	mov [esp + 20 + 256], edx
	and ecx, 0x0000ff00 
	add ecx, 0x01020009
	ret

_add_string_to_table:;EAX: old_code:code, EBX: FREE, ECX: table_size:readed_from_buf:length, EDX: FREE, ESI: in_buf, EDI: out_ptr, EBP: FREE
	mov edx, eax
	shr edx, 16; EDX = old_code
	mov ebx, edi
	;esp -= 4
	sub ebx, ebp
	mov ebp, ebx
	mov ebx, [esp + edx * 4 + 16404 + 256]; EBX: size_of_old_code_entity
	sub ebp, ebx
	inc ebx; size++
	mov edx, ecx
	shr edx, 16; edx = table_size
	mov [esp + edx * 4 + 20 + 256], ebp
	mov [esp + edx * 4 + 16404 + 256], ebx
	add edx, 2
	shr edx, cl
	add cl, dl
	add ecx, 0x00010000; 2 ** 16
	ret

section .data
	const_ones: dw 0x0001, 0x0000, 0x0001, 0x0000, 0x0001, 0x0000, 0x0001, 0x0000
	const_zeros: dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000