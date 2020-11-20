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
	gameover: .asciiz "GAME OVER, YOU LOST"
	displayAddress:	.word 0x10008000
	screenWidth: .word 512
	screenHight: .word 512
	screenUnit: .word 16
	
	limeGreen: .word 0x7bf542
	baigeGreen: .word 0xdaf542
	background: .word 0xe8d697
	padGreen: .word 0x39fc03
		             #0  4  8  12
	positionStruct: .word 56, 20, -16, displayAddress,  # current x,y | acceleration | previous pixel position to repaint
	                     # x must manuely be word aligned (inc by 4), y is automatically word aligned (inc by 1)
	                     
	platforms: .space 10 # max of 10 platforms can be existing at 1 frame
	difficulty: .word 0 # increments at a set pace, max is level 8
.text
	# global registers
          lw $s0, displayAddress # displayAddress
         # game states
      	  la $s1, positionStruct #spaced by 4
	  la $s2, platforms #spaced by 4
	  lw $s3, difficulty  
	 # dims (all already spaced by 4) 
	  lw $t4, screenUnit
	  li $t2, 4
	  lw $s4, screenWidth
	  div $s4, $t4
	  mflo $s4
	  mult $s4, $t2
	  mflo $s4 # s4 is screen width 
	  
	  lw $s5, screenHight
	  div $s5, $t4
	  mflo $s5
	  mult $s5, $t2
	  mflo $s5 # s4 is screen height 
	 # DO NOT USE S6, 7
	# END global registers
Main:
	jal FillBackground # fill backdrop first
	jal initPads # init platform
GameLoop:
	jal Catch # catch gameover 
	jal UpdateDoodleVertical # update verticality of doodle
	jal OnMove # check for player onclick events
	jal DrawDoodle # draw doodle updated position
	jal DrawPadAndHitTest # draw all pads

	li $v0, 32
	li $a0, 15 # speed todo increment as game goes on 
	syscall
	j GameLoop
	
	j Exit

OnMove: # only handle horizontal user movement and redraw, do not redraw if no movement
	addi $sp, $sp, -4
	sw $ra, 0($sp) # push ra on stack
	
	lw $t0, 0xffff0000 
	beq $t0, 1, keyboard_input
	j onMoveDone
	
	keyboard_input:	
		lw $t2, 0xffff0004 # get input (j or k)
		
		# store past x and y here
		beq $t2, 0x6a, moveLeft
		beq $t2, 0x6b, moveRight
		#todo listen for 's' and exit
		j onMoveDone
	moveLeft:
        	lw $t0, 0($s1) 
        	ble $t0, 0, onMoveDone # if at corner, dont move
        	addi $t0, $t0, -4 # move left by 1 
        	sw $t0, 0($s1) 

		j onMoveDone
	moveRight:
        	lw $t0, 0($s1) 
        	bge $t0, $s4, onMoveDone # if at corner, dont move
        	addi $t0, $t0, 4 # move left by 1 
       		sw $t0, 0($s1) 

		
	onMoveDone:
	lw $t1, 0($sp)
	addi $sp, $sp, 4 #pop ra off
	jr $t1 # return
	
DrawDoodle: 
# draws sprite based on position struct
# todo support turning around

	#replace old paint
	lw $t5, background
	
	lw $t0, 12($s1)
	sw $t5, 0($t0)
	sw $t5, 4($t0)
	
	# paint new position
	lw $t0, 0($s1) # x
    	lw $t1, 4($s1) # y
	
	mult $t1, $s4 
	mflo $t3 # y * width
	add $t4, $t3, $t0 # y + x
	add $t4, $t4, $s0, # coord + address base

	lw $t5, baigeGreen
	# fill colours 
	sw $t5, ($t4)
	sw $t5, 4($t4)

	#save last location to paint over
        sw $t4, 12($s1)
        	
	jr $ra # return

initPads:# called once on init, randomly fills the platforms array
	li $t0, 9 #counter
	ipWhile:
		li $v0, 42  #generates the random number.
		li $a1, 500  #random num between 0 and 1000
    		syscall
    		li $t1, 4 
    		mult $a0, $t1 # a0 is out actual rng number
    		mflo $t3
    		add $t3, $t3, $s0 # t3 is randomly generated location for our pad
    		
    		mult $t0, $t1 
    		mflo $t4 # array index 
    		add $t4, $t4, $s2 
    		
    		sw $t3, 0($t4)
    		beqz $t0, ipEnd
    		addi $t0, $t0,  -1
    		j ipWhile
    	ipEnd:
    	jr $ra
DrawPadAndHitTest: # draws pads from platforms
	addi $sp, $sp, -4
	sw $ra, 0($sp) # push ra on stack
	li $t0, 9 # counter
	sub $t0, $t0, $s3 # subtract number of pads from difficulty (more difficult = less pads)  
	
	li $t1, 4 
	lw $t5, padGreen # color to fill
	lw $t7, 12($s1) # last location of doodle
	addi $t7, $t7, -6 # centering factor
	lw $s6, 8($s1) # current accel of doodle
	dpfWhile:
    		mult $t0, $t1 
    		mflo $t4 # array index 
    		add $t4, $t4, $s2
    		
    		lw $t4, 0($t4) # t3 has pad coords
    		
    		sub $t6, $t4, $t7
    		abs $t6, $t6 # absolute difference of pad and doodle
    		blt $t6, 12, BounceDoodle # if the distance is close enough, we count is as contact, and bounce
    		j SkipAcc
    		BounceDoodle:
    			blez $s6, SkipAcc
    			
    			addi $sp, $sp, -4
			sw $t4, 0($sp) # push plateform coord on stack
			jal ConvertPixelPosToXY # call converter
			lw $s7, 0($sp) #get y
			addi $sp, $sp, 8 #pop y and x off
        
			sw $s7, 4($s1) # y
			li $s7, -15
			sw $s7, 8($s1) # accel
		SkipAcc:
		
		# fill colours 
		sw $t5, ($t4)
		sw $t5, 4($t4)
		sw $t5, 8($t4)
		sw $t5, 12($t4)
    		beqz $t0, dpfEnd
    		addi $t0, $t0,  -1
    		j dpfWhile
    	dpfEnd:
    	lw $t0, 0($sp) #get ra
	addi $sp, $sp, 4 #pop y and x off
	
    	jr $t0

UpdateDoodleVertical: # called to update the doodle position based on velocity
	lw $t0, 8($s1) # accell
	lw $t1, 4($s1) # y coord
	
	bltz $t0 HeadDown
	j HeadUp
	HeadDown:
		addi $t1, $t1, -1
        	sw $t1, 4($s1) # go up 
        	j udpdone
	HeadUp:
		addi $t1, $t1, 1
        	sw $t1, 4($s1) # go down
        udpdone:
        
        addi $t0 , $t0 , 1
	sw $t0 , 8($s1) # decrement accell 
        
	jr $ra
	
FillBackground: # this function fills entire play area with background colour

	lw $t5, background
	
	li $t0, 32
	mult $s4, $t0 # get screen limits
	mflo $t2 # screen limits 
	add $t2, $t2, $s0
	
	move $t1, $s0 # starting pixel pos
	
	FBwhile:
		sw $t5, 0($t1) # fill action
		addi $t1, $t1, 4 #address to fill
		bge $t1, $t2, FBend
		j FBwhile
	FBend:
	jr $ra

Catch:

	lw $t1, 4($s1) # y coord
	bgt $t1, 30, cif
	jr $ra
	cif: 
		j Exit
	jr $ra

ConvertPixelPosToXY:
	lw $t3, 0($sp) # t3 is decoding address
	addi $sp, $sp, 4 #pop param off
	
	sub $t3, $t3, $s0 # take offset off
	div $t3, $s4 
	mflo $s7 # decoded y
	mfhi $t8 # decoded x
	
	addi $sp, $sp, -4
	sw $t8, 0($sp) # push x on stack
	addi $sp, $sp, -4
	sw $s7, 0($sp) # push y on stack
	
	jr $ra
Exit:
	li $v0, 4
        la $a0, gameover
        syscall 
        
	li $v0, 10 # terminate the program gracefully
	syscall

    
