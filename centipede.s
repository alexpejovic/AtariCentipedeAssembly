#####################################################################
#
# CSC258H Winter 2021Assembly Final Project
# University of Toronto, St. George
#
# Student: Alex Pejovic, 1005936784
#
# Bitmap Display Configuration:
# -Unit width in pixels: 8
# -Unit height in pixels: 8
# -Display width in pixels: 256
# -Display height in pixels: 256
# -Base Address for Display: 0x10008000 ($gp)
#
# Which milestone is reached in this submission?
# (See the project handout for descriptions of the milestones)
# -Milestone 3
#
# Which approved additional features have been implemented?
# None
#
#####################################################################
.data
	displayAddress:	.word 0x10008000
	bugLocation: .word 814
	centipedLocation: .word 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
	centipedDirection: .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	centipedeLives: .word 3
	mushroomLocation: .word 67, 145, 264, 389, 443, 574, 743
	mushColor: .word 0xa43d2c
	shotLocation: .word -1
	fleaLocation: .word -1
	fleaColor: .word 0xff87e1
	gameState: .word 0
.text 

Main:
	jal reset_screen
	
Start_Loop:
	jal draw_start
	jal check_keystroke
	li $v0, 32
	li $a0, 100
	syscall
	
	j Start_Loop
	
Start_Game:

	jal mush_init
	
Game_Loop:
	jal check_collisions 	#checks for upcoming collisions and updates screen and .data values accordingly
	jal check_keystroke 	#checks for keystroke and updates game values accordingly
	jal draw_resources	#draws the game screen
	li $v0, 32
	li $a0, 33
	syscall

	j Game_Loop
	
End_Loop:
	jal draw_end
	jal check_keystroke
	li $v0, 32
	li $a0, 100
	syscall
	
	j End_Loop

Exit:
	li $v0, 10		# terminate the program gracefully
	syscall
	

		
#	1.checks for collisions between objects erases
#	2. erases objects previous positions if they've been moved
#	3. updates locations of those objects in .data
check_collisions:

	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	jal move_bullet
	jal move_centipede
	jal move_flea

	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
# function to detect any keystroke
check_keystroke:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t8, 0xffff0000
	beq $t8, 1, get_keyboard_input # if key is pressed, jump to get this key
	addi $t8, $zero, 0
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	

#functions to draw all objects onto screen
draw_resources:

	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	jal disp_centiped
	jal disp_bullet
	jal disp_bug
	jal draw_flea
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra


# function to display a static centiped	
disp_centiped:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	addi $a2, $zero, 10	 # load a3 with the loop count (10)
	la $a0, centipedLocation # load the address of the array into $a1
	la $a1, centipedDirection # load the address of the array into $a2
	
	lw $t2, displayAddress  # $t2 stores the base address for display
	
	arr_loop:	#iterate over the loops elements to draw each body in the centiped
	lw $t1, 0($a0)		 # load a word from the centipedLocation array into $t1
	lw $t5, 0($a1)		 # load a word from the centipedDirection  array into $t5
	
	li $t3, 0xff0000 #Load body colour into $t3
	bne $a2, 1, color_body #If we are on last part of centipede to display (head), change to head color
	li $t3, 0x00ff00
	
	color_body:
	sll $t4,$t1, 2		
	add $t4, $t2, $t4	# load $t4 with absolute memory of bug location
	sw $t3, 0($t4)		# paint the body
	
	addi $a0, $a0, 4	 # increment $a1 by one, to point to the next element in the array
	addi $a1, $a1, 4
	addi $a2, $a2, -1	 # decrement $a3 by 1
	bne $a2, $zero, arr_loop
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
	
#changes location values of centipede based on its current position
move_centipede:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	jal erase_centipede
	
	addi $a2, $zero, 10	 # load a3 with the loop count (10)
	la $a0, centipedLocation # load the address of the array into $a1
	la $a1, centipedDirection # load the address of the array into $a2
	lw $t0, displayAddress
	
	#if centipede is dead, reset its position
	la $t1, centipedeLives
	lw $t2, 0($t1)
	bnez $t2, move_centi_loop
	li $t3, 3
	sw $t3, 0($t1)
	jal reset_centi_pos
	j end_move_centi_func

	move_centi_loop:
	
	lw $t1, 0($a0)		 # load a word from the centipedLocation array into $t1
	lw $t5, 0($a1)		 # load a word from the centipedDirection  array into $t5
	lw $t8, mushColor	
	
	#Load color of next centipede location in $t2
	add $t2, $t1, $t5
	sll $t2, $t2, 2
	add $t2, $t2, $t0 	
	lw $t2, 0($t2)
	
	#make centipede dodge mushroom 
	beq $t2, $t8, shift_down

	#if (arr + 1/ 32 == 0 & direction == 1) then arr = arr + 32, direction == -1
	#if(arr/ 32 == 0 and direction == -1) then arr = arr + 32, direction == 1
	beq $t1, 768, go_right
	beq $t1, 799, go_left
	
	addi $t6, $t1, 1
	li $t7, 32
	div $t6, $t7
	mfhi $t6
	div $t1, $t7
	mfhi $t7
	
	bnez $t6, not_right
	bne $t5, 1, not_right
	j shift_down
	
	not_right:	
	bnez $t7, shift_hor
	bne $t5, -1, shift_hor

	shift_down:	
	addi $t1, $t1, 32
	mul $t5, $t5, -1
	j end_func1
	
	go_right:
	li $t5, 1
	add $t1, $t1, $t5
	j end_func1
	
	go_left:
	li $t5, -1
	add $t1, $t1, $t5
	j end_func1

	shift_hor:
	add $t1, $t1, $t5	#store new location in $t1
	### end of if statement

	end_func1:
	
	sw $t1, 0($a0)		#store new centipede location in array
	sw $t5, 0($a1)		#store new centipede movement in array
	
	addi $a0, $a0, 4	 # increment $a0 by one, to point to the next element in the array
	addi $a1, $a1, 4	
	addi $a2, $a2, -1	 # decrement $a3 by 1
	bne $a2, $zero, move_centi_loop
	
	end_move_centi_func:
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

	
# function to get the input key
get_keyboard_input:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t3, gameState
	lw $t2, 0xffff0004
	
	bne $t3, 1, check_start
	beq $t2, 0x6A, respond_to_j
	beq $t2, 0x6B, respond_to_k
	beq $t2, 0x78, respond_to_x
	
	check_start:
	beq $t2, 0x73, respond_to_s
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

	
# Call back function of j key
respond_to_j:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	la $t0, bugLocation	# load the address of buglocation from memory
	lw $t1, 0($t0)		# load the bug location itself in t1
	
	lw $t2, displayAddress  # $t2 stores the base address for display
	li $t3, 0x000000	# $t3 stores the black colour code
	
	sll $t4,$t1, 2		# $t4 the bias of the old buglocation
	add $t4, $t2, $t4	# $t4 is the address of the old bug location
	sw $t3, 0($t4)		# paint the first (top-left) unit white.
	
	beq $t1, 800, skip_movement # prevent the bug from getting out of the canvas
	addi $t1, $t1, -1	# move the bug one location to the right
	skip_movement:
	sw $t1, 0($t0)		# save the bug location

	li $t3, 0xffffff	# $t3 stores the white colour code
	
	sll $t4,$t1, 2
	add $t4, $t2, $t4
	sw $t3, 0($t4)		# paint the first (top-left) unit white.
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra


# Call back function of k key
respond_to_k:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	la $t0, bugLocation	# load the address of buglocation from memory
	lw $t1, 0($t0)		# load the bug location itself in t1
	
	lw $t2, displayAddress  # $t2 stores the base address for display
	li $t3, 0x000000	# $t3 stores the black colour code
	
	sll $t4,$t1, 2		# $t4 the bias of the old buglocation
	add $t4, $t2, $t4	# $t4 is the address of the old bug location
	sw $t3, 0($t4)		# paint the block with black
	
	beq $t1, 831, skip_movement2 #prevent the bug from getting out of the canvas
	addi $t1, $t1, 1	# move the bug one location to the right
	skip_movement2:
	sw $t1, 0($t0)		# save the bug location

	li $t3, 0xffffff	# $t3 stores the white colour code
	
	sll $t4,$t1, 2
	add $t4, $t2, $t4
	sw $t3, 0($t4)		# paint the block with white
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
	
#call back function to pressing x
respond_to_x:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	la $t1, shotLocation #Load address of location of bullet into $t1
	lw $t2, 0($t1)  #Load relative location of bullet into $t2
	la $t3, bugLocation #Load address of location of bug into $t3
	lw $t4, 0($t3) #Load relative location of bug into $t4
	
	bne $t2, -1, dont_shoot #If bullet is in air, don't shoot
	sw $t4, 0($t1)
	
	dont_shoot:
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	

#call back function to pressing s	
respond_to_s:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t0, gameState
	
	beq $t0, 1, dont_start_game
	jal init_game
	jal reset_screen
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	j Start_Game
	
	dont_start_game:
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra


###Draw the mushrooms
mush_init:

	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	addi $t0, $zero, 9	 # load a3 with the loop count (10)
	lw $t2, displayAddress  # $t2 stores the base address for display
	lw $t3, mushColor #load t3 with mushroom color
	
	#random num generator setup
	li $v0, 42
	li $a1, 734
	
	mush_loop:
	
	#store random number between 32 and 799 in $a0
	li $a0, 0
	syscall
	
	#store relative location of mushroom in $t1
	addi $t1, $a0, 32
	
	#paint location
	sll $t4,$t1, 2		
	add $t4, $t2, $t4	# load $t4 with absolute memory of bug location
	sw $t3, 0($t4)		# paint the mushroom with brown
	
	addi $t0, $t0, -1
	bne $t0, $zero, mush_loop
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
	
#displays bullet at current position	
disp_bullet:

	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	la $t1, shotLocation #Load address of location of bullet into $t1
	lw $t2, 0($t1) #Load relative location of bullet into $t2
	lw $t4, displayAddress
	
	beq $t2, -1, dont_draw_bullet #don't draw bullet if it is not in air
	
	#store proper new pixel location of bullet in $t5 and draw white in that location
	sll $t5, $t2, 2
	add $t5, $t5, $t4
	li $t3, 0xfffffe
	sw $t3, 0($t5)
	
	dont_draw_bullet:
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
	
#erases previous bullet location and moves its position in .data	
move_bullet:

	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	la $t1, shotLocation #Load address of location of bullet into $t1
	lw $t2, 0($t1) #Load relative location of bullet into $t2
	
	beq $t2, -1, dont_move_bullet #don't draw bullet if it is not in air
	
	li $t3, 0x000000 #load black into $t3
	lw $t4, displayAddress #load base address of display into $t4
	
	#store proper past pixel location of bullet in $t5 and draw black in that location
	sll $t5, $t2, 2
	add $t5, $t5, $t4
	sw $t3, 0($t5)
	
	#Load 0 into $t6 if past bullet location is at top of screen
	li $t6, 32
	div $t2, $t6
	mflo $t6
	
	bnez $t6, raise_bullet #If bullet was at top of screen, we change the array so that bullet doesn't get drawn off screen
	li $t7, -1
	sw $t7, 0($t1)
	j dont_move_bullet
	
	raise_bullet:
	#change the value of $t2 to have the next location of bullet
	addi $t2, $t2, -32
	
	#store color of new bullet location at $t5
	sll $t8, $t2, 2
	add $t8, $t8, $t4
	lw $t5, 0($t8)
	
	#if there is a mushroom at the next location of the bullet, destroy bullet and mushroom
	lw $t6, mushColor
	bne $t5, $t6, not_mush
	li $t7, -1
	sw $t7, 0($t1)
	sw $t3, 0($t8)
	j dont_move_bullet
	
	#if there is a centipede at the next location of the bullet, destroy bullet and decrement centipede lives
	not_mush:
	li $t6, 0xff0000
	bne $t5, $t6, not_cent
	li $t7, -1
	sw $t7, 0($t1)
	la $t1, centipedeLives
	lw $t0, 0($t1)
	addi $t0, $t0, -1
	sw $t0, 0($t1)
	j dont_move_bullet
	
	not_cent:
	sw $t2, 0($t1)	#store new bullet location in array
	
	dont_move_bullet:
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
	
#displays bug blaster at current position
disp_bug:

	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	la $t0, bugLocation	# load the address of buglocation from memory
	lw $t1, 0($t0)		# load the bug location itself in t1
	
	lw $t2, displayAddress  # $t2 stores the base address for display
	li $t3, 0xffffff	# $t3 stores the white colour code
	
	sll $t4,$t1, 2		# $t4 the bias of the old buglocation
	add $t4, $t2, $t4	# $t4 is the address of the old bug location
	sw $t3, 0($t4)		# paint the block with white

	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
	

	
	
#paints entire screen black
reset_screen:

	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t0, displayAddress
	add $t1, $zero, $zero
	addi $t2, $zero, 1024
	li $t3, 0x000000
	
	reset_screen_loop:
	sll $t4, $t1, 2
	add $t4, $t4, $t0
	sw $t3, 0($t4)
	
	addi $t2, $t2, -1
	addi $t1, $t1, 1
	bnez $t2, reset_screen_loop
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
erase_centipede:

	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	addi $a2, $zero, 10	 # load a3 with the loop count (10)
	la $a0, centipedLocation # load the address of the array into $a1
	la $a1, centipedDirection # load the address of the array into $a2
	
	lw $t2, displayAddress  # $t2 stores the base address for display
	li $t3, 0x000000 #load $t3 with black
	
	erase_centi_loop:	#iterate over the loops elements to draw each body in the centiped
	lw $t1, 0($a0)		 # load a word from the centipedLocation array into $t1
	lw $t5, 0($a1)		 # load a word from the centipedDirection  array into $t5
	
	sll $t4,$t1, 2		
	add $t4, $t2, $t4	# load $t4 with absolute memory of bug location
	sw $t3, 0($t4)		# paint the body
	
	addi $a0, $a0, 4	 # increment $a1 by one, to point to the next element in the array
	addi $a1, $a1, 4
	addi $a2, $a2, -1	 # decrement $a3 by 1
	bne $a2, $zero, erase_centi_loop
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

#reset centipede position	
reset_centi_pos:

	jal erase_centipede
	
	#reset centipede array
	la $t0, centipedLocation
	la $t1, centipedDirection
	addi $t2, $zero, 10
	add $t3, $zero, $zero
	addi $t4, $zero, 1
	
	reset_centi_loop:
	sw $t3, 0($t0)
	sw $t4, 0($t1)
	
	addi $t3, $t3, 1
	addi $t0, $t0, 4
	addi $t1, $t1, 4
	
	addi $t2, $t2, -1
	bnez $t2, reset_centi_loop

	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

init_game:

	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	#initialize bug location
	la $t0, bugLocation
	li $t1, 814
	sw $t1, 0($t0)
	
	#initialize flea location
	la $t0, fleaLocation
	li $t1, -1
	sw $t1, 0($t0)
	
	#initialize shot location
	la $t0, shotLocation
	li $t1, -1
	sw $t1, 0($t0)
	
	#initialize centipede lives
	la $t0, centipedeLives
	li $t1, 3
	sw $t1, 0($t0)
	
	#initialize game state
	la $t0, gameState
	li $t1, 1
	sw $t1, 0($t0)
	
	#initialize centipede position
	jal reset_centi_pos

	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
move_flea:
	
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	la $t0, fleaLocation
	lw $t1, 0($t0)
	lw $t2, fleaColor
	lw $t3, displayAddress
	li $t4, 0x000000
	
	#if flea not on screen, possibly initialize it, otherwise erase last location and update
	beq $t1, -1, create_flea
	
	#erase previous flea location
	sll $t5, $t1, 2
	add $t5, $t5, $t3
	sw $t4, 0($t5)
	
	#set $t5 to 0 if flea at bottom of screen
	addi $t6, $t1, -1024
	li $t5, 32
	div $t6, $t5
	mflo $t5
	
	#if flea at bottom of screen, kill it
	bnez $t5, move_flea_down
	li $t6, -1
	sw $t6, 0($t0)
	j end_move_flea
	
	move_flea_down:
	#move flea one space down
	addi $t1, $t1, 32
	sw $t1, 0($t0)
	j end_move_flea
	
	create_flea:
	jal generate_flea
	j end_move_flea2
	
	end_move_flea:
	
	#store color of new flea location in $t5
	sll $t5, $t1, 2
	add $t5, $t5, $t3
	lw $t5, 0($t5)
	
	#if flea intersecting bug blaster, end game
	li $t6, 0xffffff
	bne $t5, $t6, end_move_flea2
	jal reset_screen
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	la $t0, gameState
	li $t1, 2
	sw $t1, 0($t0)
	j End_Loop
	
	end_move_flea2:
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
generate_flea:

	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	la $t0, fleaLocation
	lw $t1, 0($t0)
	
	#$a0 == 0 1/20 times
	li $v0, 42
	li $a0, 0
	li $a1, 20
	syscall
	
	#if $a0 == 0, initialize flea, otherwise do nothing
	bnez $a0, dont_init_flea
	
	#give flea random starting location
	li $v0, 42
	li $a0, 0
	li $a1, 31
	syscall
	
	#insert new starting location in array
	sw $a0, 0($t0)
	
	dont_init_flea:
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
		
#Draw flea on screen
draw_flea:
	
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	la $t0, fleaLocation
	lw $t1, 0($t0)
	lw $t2, fleaColor
	
	#if flea on screen, draw it
	beq $t1, -1, end_draw_flea
	lw $t3, displayAddress
	sll $t5, $t1, 2
	add $t5, $t5, $t3
	sw $t2, 0($t5)
	
	#if flea is allowed to draw mushroom at certain location, give it a 1/11 change to draw mush
	li $v0, 42
	li $a0, 0
	li $a1, 10
	syscall
	
	#if $a0 == 0, then try to draw mushroom
	bnez $a0, end_draw_flea
	
	addi $t1, $t1, -32
	
	#if mushroom is at a valid location, draw it
	ble $t1, 31, end_draw_flea
	bge $t1, 734, end_draw_flea
	
	lw $t2, mushColor
	sll $t5, $t1, 2
	add $t5, $t5, $t3
	sw $t2, 0($t5)
	
	end_draw_flea:
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
	
#Draw start screen
draw_start:

	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t0, displayAddress
	li $t1, 528
	sll $t1, $t1, 2
	add $t1, $t1, $t0
	li $t2, 0xff00ff
	sw $t2, 0($t1)

	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
#Draw end screen
draw_end:

	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t0, displayAddress
	li $t1, 528
	sll $t1, $t1, 2
	add $t1, $t1, $t0
	li $t2, 0x00ff00
	sw $t2, 0($t1)

	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
