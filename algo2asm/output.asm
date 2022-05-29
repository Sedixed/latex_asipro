; ASM file obtained from a LaTeX file

	const ax,main
	jmp ax

:div_err_str
@string "Erreur : Division par 0 impossible\n"

:div_err
	const ax,div_err_str
	callprintfs ax
	end

:non_tail_recursive
; Get the n variable and push it in the top of the stack
	const ax,2
	const bx,1
	mul ax,bx
	cp bx,sp
	sub bx,ax
	loadw ax,bx
	push ax
; Reading the number 0
	const ax,0
; Push a temp variable on the stack
	push ax
; Comparison number of type "equals" (ID: 0)
	pop ax
	pop bx
	const cx,equals_0
	cmp ax,bx
	jmpc cx
; False case (ID: 0)
	const ax,0
	push ax
	const ax,end_equals_0
	jmp ax
; True case (ID: 0)
:equals_0
	const ax,1
	push ax
; End of comparison number of type "equals" (ID: 0)
:end_equals_0
; Begin of the "if" condition (ID: 1)
	pop ax
	const bx,0
	const cx,else_1
	cmp ax,bx
	jmpc cx
; True case of the "if" condition (ID: 1)
; Reading the number 1
	const ax,1
; Push a temp variable on the stack
	push ax
	pop ax
	ret
	const ax,end_if_1
	jmp ax
:else_1
; False case of the "if" condition (ID: 1)
:end_if_1
; End of the loop/condition (ID: 1)
; Reading the number 0
	const ax,0
; Push a temp variable on the stack
	push ax
; Add the k variable in the stack
	pop ax
	push ax
; Get the n variable and push it in the top of the stack
	const ax,2
	const bx,2
	mul ax,bx
	cp bx,sp
	sub bx,ax
	loadw ax,bx
	push ax
; Add the p variable in the stack
	pop ax
	push ax
; Beginning of the "do while" loop (ID: 2)
:while_2
; Get the k variable and push it in the top of the stack
	const ax,2
	const bx,1
	mul ax,bx
	cp bx,sp
	sub bx,ax
	loadw ax,bx
	push ax
; Reading the number 2
	const ax,2
; Push a temp variable on the stack
	push ax
; Comparison of type "lower than" (ID: 3)
	pop ax
	pop bx
	const cx,lower_than_3
	sless bx,ax
	jmpc cx
; False case (ID: 3)
	const ax,0
	push ax
	const ax,end_lower_than_3
	jmp ax
; True case (ID: 3)
:lower_than_3
	const ax,1
	push ax
; End of comparison of type "lower than" (ID: 3)
:end_lower_than_3
	pop ax
	const bx,0
	const cx,end_while_2
	cmp ax,bx
	jmpc cx
; Get the p variable and push it in the top of the stack
	const ax,2
	const bx,0
	mul ax,bx
	cp bx,sp
	sub bx,ax
	loadw ax,bx
	push ax
; Get the n variable and push it in the top of the stack
	const ax,2
	const bx,4
	mul ax,bx
	cp bx,sp
	sub bx,ax
	loadw ax,bx
	push ax
; Reading the number 1
	const ax,1
; Push a temp variable on the stack
	push ax
; Substracting two expressions
	pop ax
	pop bx
	sub bx,ax
; Push a temp variable on the stack
	push bx
; Call the test function
	const bx,non_tail_recursive
	call bx
; Pop the called function args
	pop dx
; Push the returned value on the stack
; Push a temp variable on the stack
	push ax
; Adding two expressions
	pop ax
	pop bx
	add ax,bx
; Push a temp variable on the stack
	push ax
; Update the p variable in the stack
	const ax,2
	const bx,1
	mul ax,bx
	cp bx,sp
	sub bx,ax
	pop ax
	storew ax,bx
; Get the k variable and push it in the top of the stack
	const ax,2
	const bx,1
	mul ax,bx
	cp bx,sp
	sub bx,ax
	loadw ax,bx
	push ax
; Reading the number 1
	const ax,1
; Push a temp variable on the stack
	push ax
; Adding two expressions
	pop ax
	pop bx
	add ax,bx
; Push a temp variable on the stack
	push ax
; Update the k variable in the stack
	const ax,2
	const bx,2
	mul ax,bx
	cp bx,sp
	sub bx,ax
	pop ax
	storew ax,bx
	const ax,while_2
	jmp ax
:end_while_2
; End of the loop/condition (ID: 2)
; Get the p variable and push it in the top of the stack
	const ax,2
	const bx,0
	mul ax,bx
	cp bx,sp
	sub bx,ax
	loadw ax,bx
	push ax
	pop ax
	pop dx
	pop dx
	ret

:main
; Stack preparation
	const bp,stack
	const sp,stack
	const ax,2
	sub sp,ax
	const ax,2
	push ax
	const ax,non_tail_recursive
	call ax
	push ax
	cp ax,sp
	callprintfd ax
	end

;Stack zone
:stack
@int 0
