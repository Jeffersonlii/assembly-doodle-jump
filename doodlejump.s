
#####################################################################
#
# CSCB58 Fall 2020 Assembly Final Project
# University of Toronto, Scarborough
#
# Student: Name, Student Number
#
# Bitmap Display Configuration:
# - Unit width in pixels: 16					     
# - Unit height in pixels: 16
# - Display width in pixels: 512
# - Display height in pixels: 512
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestone is reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 1/2/3/4/5 (choose the one the applies)
#
# Which approved additional features have been implemented?
# (See the assignment handout for the list of additional features)
# 1. (fill in the feature, if any)
# 2. (fill in the feature, if any)
# 3. (fill in the feature, if any)
# ... (add more if necessary)
#
# Link to video demonstration for final submission:
# - (insert YouTube / MyMedia / other URL here). 
#
# Any additional information that the TA needs to know:
# - (write here, if any)
#
#####################################################################

.data
	p: .asciiz "HELP MEEE "
	displayAddress:	.word	0x10008000
	screenWidth: .word 512
	screenHight: .word 512
	screenUnit: .word 16
	
	limeGreen: .word 0x7bf542
	baigeGreen: .word 0xdaf542
	background: .word 0xe8d697
.text
	# global registers
	
	  # colour
	  lw $s0, displayAddress # displayAddress
	  lw $s1, limeGreen	# lime green
	  lw $s2, baigeGreen	# baige green
	  lw $s3, background    # background baige
	  
	  # dims (all already spaced by 4)
	  lw $t4, screenUnit
	  li $t2, 4
	  lw $s4, screenWidth
	  div $s4, $t4
	  mflo $s4
	  mult $s4, $t2
	  mflo $s4
	  
	  lw $s5, screenHight
	  div $s5, $t4
	  mflo $s5
	  mult $s5, $t2
	  mflo $s5
	  
	  # game states
	  li $s6, 0 # vertical velocity
	  
	  li $t8, 0 # doodle x position 
	  li $t9, 0 # doodle y position 
	  # util
	  li $v1, 0 # return $ra holder when we nest functions
	# END global registers
	
GameLoop:
	jal onMove # first check player position and update accordingly
	#li $v0, 32 # sleep, enable later
	#li $a0, 1000
	#syscall
	# todo pain background
	j GameLoop
	j Exit

onMove:# only handle horizontal user movement and redraw, do not redraw if no movement
	move $v1, $ra# save return address 
	lw $t0, 0xffff0000 
	beq $t0, 1, keyboard_input
	j onMoveDone
	
	keyboard_input:
		lw $t2, 0xffff0004
		
		beq $t2, 0x6a, moveLeft
		beq $t2, 0x6b, moveRight
		j onMoveDone
	moveLeft:
		subi $t8, $t8, 4
		jal DrawDoodle
		j onMoveDone
	moveRight:
		addi $t8, $t8, 4
		jal DrawDoodle
	onMoveDone:

	jr $v1 # return
	
DrawDoodle: 
# draws sprite based on $t8 = x, $t9 = y
# todo support turning around
	
	mult $t9, $s4 
	mflo $t0 # y * width
	add $t0, $t9, $t8 # y + x
	add $t0, $t0, $s0, # coord + address base
	
       	#paint new 

	sw $s2, ($t0)
	sw $s2, 4($t0)

	jr $ra # return

DrawPadSolid:

Print:
 	li $v0, 4
        la $a0, p
        syscall 
        jr $ra # return

Exit:
	li $v0, 10 # terminate the program gracefully
	syscall

    
