
SECTION .data
	format:	db "%s", 0x0a, 0
	expext: db "expected '%c' at index %i but found '%c'", 0x0a,  0
	succes: db "JSON is valid!", 0x0a, 0
	lit_true: db "true", 0
	lit_false: db "false", 0
	lit_null: db "null", 0

SECTION .bss
	buffer 	resb 1024
	tmpbuf 	resb 1024
	exp_chr resb 4
	buflen 	equ 1024
	index 	resb 4

SECTION .text
	global 	main
	extern 	printf

readfile:
	push ebp
	mov ebp, esp
	sub esp, 4

	mov eax, 5 				; syscall for open
	mov ebx, [ebp+8] 		; first argument is filename
	mov ecx, 0 				; read only
	int 0x80
	mov [ebp-4], eax 		; move file descriptor into local-var

	cmp eax, 0
	jl error

	mov eax, 3 				; syscall for read
	mov ebx, [ebp-4] 		; file descriptor
	mov ecx, tmpbuf 		; buffer to fill
	mov edx, buflen 		; buffer size
	int 0x80

	mov eax, 6 				; syscall for close
	mov ebx, [ebp-4] 		; file descriptor
	int 0x80

	mov esp, ebp
	pop ebp
	ret
	
validate:
	push ebp
	mov ebp, esp
	
	mov byte[index], 0
	call object

	push succes
	push format
	call printf

	mov esp, ebp
	pop ebp
	ret

object:
	push ebp
	mov ebp, esp

	mov ebx, [index]
	mov byte [exp_chr], '{'
	cmp byte [buffer+ebx], '{'
	jne error

	inc dword[index]

	mov ebx, [index]
	cmp byte[buffer+ebx], '"'
	jne .end

	.item:
		call string
		mov ebx, [index]
		mov byte[exp_chr], ':'
		cmp byte[buffer+ebx], ':'
		jne error
		inc dword[index]
		call value
		mov ebx, [index]
		cmp byte[buffer+ebx], ','
		jne .end
		inc dword[index]
		jmp .item

	.end:
		mov ebx, [index]
		mov byte[exp_chr], '}'
		cmp byte[buffer+ebx], '}'
		jne error

		inc dword[index]
		mov esp, ebp
		pop ebp
		ret

string:
	push ebp
	mov ebp, esp
	
	mov ebx, [index]
	
	mov byte[exp_chr], '"'
	cmp byte[buffer+ebx], '"'
	jne error

	.loop:
		inc dword[index]
		mov ebx, [index]
		mov byte[exp_chr], '"'
		cmp byte[buffer+ebx], 0
		je error
		cmp byte[buffer+ebx], '"'
		jne .loop

	inc dword[index]
	mov esp, ebp
	pop ebp
	ret

cmp_str:
	push ebp
	mov ebp, esp

	mov ebx, [index]
	mov ecx, [ebp+8]
	mov eax, 0

	.loop:
		mov dh, byte[ecx+eax]
		cmp dh, 0
		je .end
		cmp byte[buffer+ebx], dh
		jne .noteq
		inc eax
		inc ebx
		jmp .loop

	.noteq:
		mov eax, 0
		jmp .end

	.end:
		mov esp, ebp
		pop ebp
		ret

num:
	push ebp
	mov ebp, esp

	mov ecx, -1

	mov byte[exp_chr], 'n'
	mov ebx, [index]
	cmp byte[buffer+ebx], '-'
	je .loop
	cmp byte[buffer+ebx], '0'
	jl error
	cmp byte[buffer+ebx], '9'
	jg error
	jmp .loop

	.dot:
		cmp ecx, 0
		jge error
		not ecx
		jmp .loop

	.loop:
		inc dword[index]
		mov ebx, [index]
		cmp byte[buffer+ebx], '.'
		je .dot
		cmp byte[buffer+ebx], '0'
		jl .end
		cmp byte[buffer+ebx], '9'
		jg .end
		jmp .loop

	.end:
		mov esp, ebp
		pop ebp
		ret

array:
	push ebp
	mov ebp, esp

	mov ebx, [index]
	mov byte [exp_chr], '['
	cmp byte [buffer+ebx], '['
	jne error
	
	inc dword[index]
	mov ebx, [index]
	cmp byte [buffer+ebx], ']'
	je .end
	
	.item:
		call value
		mov ebx, [index]
		cmp byte[buffer+ebx], ','
		jne .end
		inc dword[index]
		jmp .item

	.end:
		mov ebx, [index]
		mov byte[exp_chr], ']'
		cmp byte[buffer+ebx], ']'
		jne error

	inc dword[index]
	mov esp, ebp
	pop ebp
	ret

literal:
	push ebp
	mov ebp, esp

	mov byte[exp_chr], 'l'
	
	push lit_true
	call cmp_str
	add esp, 4
	cmp eax, 0
	jg .end

	push lit_false
	call cmp_str
	add esp, 4
	cmp eax, 0
	jg .end

	push lit_null
	call cmp_str
	add esp, 4
	cmp eax, 0
	jle error

	.end:
		add [index], eax
		mov esp, ebp
		pop ebp
		ret

value:
	push ebp
	mov ebp, esp

	mov ebx, [index]

	mov dword[exp_chr], 'v'
	cmp byte[buffer+ebx], '"'
	je .string
	cmp byte[buffer+ebx], '{'
	je .object
	cmp byte[buffer+ebx], '['
	je .array
	cmp byte[buffer+ebx], '-'
	je .num
	cmp byte[buffer+ebx], '0'
	jl .literal
	cmp byte[buffer+ebx], '9'
	jg .literal
	jmp .num

	.string:
		call string
		jmp .end
	
	.object:
		call object
		jmp .end

	.array:
		call array
		jmp .end

	.num:
		call num
		jmp .end

	.literal:
		call literal
		jmp .end

	.end:
		mov esp, ebp
		pop ebp
		ret

strip:
	push ebp
	mov ebp, esp

	mov ebx, 0
	mov ecx, 0
	mov esi, -1

	.loop:
		cmp byte[tmpbuf+ebx], '"'  
		je .qoute
		cmp esi, 0 					; within string
		jge .copy 
		cmp byte[tmpbuf+ebx], ' ' 	
		je .incr
		cmp byte[tmpbuf+ebx], 10 	; newline
		je .incr
		cmp byte[tmpbuf+ebx], 9 	; tab
		je .incr
		cmp byte[tmpbuf+ebx], 0 	; eof
		je .end
		jmp .copy

	.qoute:
	 	not esi	

	.copy:
		mov edx, [tmpbuf+ebx]
		mov [buffer+ecx], edx
		inc ebx
		inc ecx
		jmp .loop

	.incr:
		inc ebx
		jmp .loop

	.end:
		inc ecx
		mov byte[buffer+ecx], 0	
		
		mov esp, ebp
		pop ebp
		ret

main:
	push ebp
	mov ebp, esp

	mov esi, dword[ebp+12] 	; address of argv
	add esi, 4 				; get second argument

	push dword[esi]  		; push first argv as filename
	call readfile

	call strip  			; strip whitespace from buffer

	push buffer 			; print result
	push format
	call printf

	call validate 

	mov ebx, 0
	mov eax, 0x1
	int 0x80

error:
	mov ebx, [index]
	mov ecx, [buffer+ebx]
	push ecx 				; push current char
	push ebx 				; push index
	mov ebx, [exp_chr]  
	push ebx 				; push expected character
	push expext 			; format for error message
	call printf
	mov ebx, 1
	mov eax, 0x1
	int 0x80


