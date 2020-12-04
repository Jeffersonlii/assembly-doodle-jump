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
# 1. Fancier graphics (better doodle sprite with left/right facing logic), with start/end screens
# 2. 
# 3. (fill in the feature, if any)
# ... (add more if necessary)
#
# Link to video demonstration for final submission:
# - (insert YouTube / MyMedia / other URL here). 
#
# Any additional information that the TA needs to know:
# - please use mustafa's MARS fork to avoid crashing
# - game speeds up at every 50 point interval
# todo
# - jump physics
# - rocket
#####################################################################

.data
	debug1: .asciiz "\n bruh \n"
	debug2: .asciiz "\n bruh2 \n"
	
	gameover: .asciiz "GAME OVER, YOU LOST"
	displayAddress:	.word 0x10008000
	screenWidth: .word 512
	screenHight: .word 512
	screenUnit: .word 16
	
	pantsGreen: .word 0x32a858
	baigeGreen: .word 0xe3cc39
	background: .word 0xf5e8b3
	padGreen: .word 0x39fc03
	eyeBlack: .word 0x000000
	
	difficulty: .word 0 # increments at a set pace, max is level 15
	score: .word 0, 0, 0, 0, 0 # the current score, difficulty should scale off score
				   # 0 - 3 are digits to the score, 4th is the full score
				   # 1,7,3,4,1734

		             #0    4    8              12 16 
	positionStruct: .word 56, 20, -30, displayAddress, 0 # current x | y | acceleration | previous pixel position to repaint | direction facing, 0 for left, 1 for right
	                     # x must manuely be word aligned (inc by 4), y is automatically word aligned (inc by 1)
	                     
	platforms: .space 20 # max of 10 platforms can be existing at 1 frame, + 10 platforms last position

	
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
	jal WipeBoard # fill backdrop first
	jal initPads # init platform
	
	li $t0, 9
	mult $t0, $s4
	mflo $t0
	add $a1, $s0, $t0 
	add $a1, $a1, 12 #calc starting position for logo 
	
	jal PaintStartGraphic
	InitOnPress: # waits for user imput before starting the game 
		li $v0, 32
		li $a0, 50
		syscall
		lw $t0, 0xffff0000 
		bne $t0, 1, InitOnPress
		
		jal WipeBoard # wipe start screen before playing game
		j GameLoop

GameLoop:
	jal Catch # catch gameover 
	jal UpdateDoodleVertical # update verticality of doodle
	jal OnMove # check for player onclick events
	jal MoveDoodle # move doodle updated position
	jal DrawPadAndHitTest # draw all pads
	jal DisplayScore
	
	li $v0, 32
	li $t0, 30 # base speed
	li $t1, 2 # multiplier 
	mult $s3, $t1
	mflo $t2  
	sub $t0, $t0, $t2
	move $a0, $t0 # speed increases as difficulty goes up 
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
		beq $t2, 0x73, IsS # listen for 's' and exit
		j onMoveDone
	moveLeft:
        	lw $t0, 0($s1) 
        	addi $t0, $t0, -4 # move left by 1 
        	sw $t0, 0($s1) 
	
		li $t0, 0 # update facing direction 
        	sw $t0, 16($s1) 
		j onMoveDone
	moveRight:
        	lw $t0, 0($s1) 
        	addi $t0, $t0, 4 # move left by 1 
       		sw $t0, 0($s1) 
	
		li $t0, 1 # update facing direction 
        	sw $t0, 16($s1) 
		
	onMoveDone:
	lw $t1, 0($sp)
	addi $sp, $sp, 4 #pop ra off
	jr $t1 # return
	
MoveDoodle: 
# draws sprite based on position struct
# todo support turning around
	addi $sp, $sp, -4
	sw $ra, 0($sp) # push ra on stack
	
	# calc new pos
	lw $t2, 0($s1) # x
    	lw $t1, 4($s1) # y
	
	mult $t1, $s4 
	mflo $t3 # y * width
	add $t4, $t3, $t2 # y + x
	add $t4, $t4, $s0, # coord + address base
	
	#replace old paint
	lw $t0, 12($s1) # old pos
	
	move $a0, $t0
	
	li $a1, 0 # replace old drawing 
	jal DrawDoodle
	
	move $a0, $t4
	li $a1, 1 # draw doodle 
	jal DrawDoodle

	#save last location to paint over
        sw $t4, 12($s1)
        
	lw $t1, 0($sp)
	addi $sp, $sp, 4 #pop ra off
	jr $t1 # return
DrawDoodle: # $a0 is position of doodle, # $a1 is colour mode // 1 for doodle, 0 for background
	    # must not edit the $t4 register

	lw $t8, background # pants colour
	beqz $a1, ddIfBackground
	j ddElseIdDoodle
	ddIfBackground:
		lw $t5, background # base colour
		lw $t6, background # eye colour
		lw $t7, background # pants colour
		j ddelse
	ddElseIdDoodle:
		lw $t5, baigeGreen
		lw $t6, eyeBlack # eye colour
		lw $t7, pantsGreen # pants colour
	ddelse:
	
	sw $t6, 0($a0)
	sw $t6, 8($a0)
	sub $a0, $a0, $s4
	sw $t7, 0($a0)
	sw $t7, 4($a0)
	sw $t7, 8($a0)
	sub $a0, $a0, $s4
	sw $t5, 0($a0)
	sw $t5, 4($a0)
	sw $t5, 8($a0)
	sub $a0, $a0, $s4
	
       	lw $t0, 16($s1) 
        	
	beqz $t0 facingleft
	j facingright
	facingleft:
		sw $t6, 0($a0)# eye coulour
		sw $t5, 4($a0)
		sw $t5, 8($a0) 
		sw $t5, -4($a0)
		sw $t5, -8($a0)
		
		sw $t8, 12($a0)  # prev destroy nose
		sw $t8, 16($a0)
		j endfacing
	facingright:
		sw $t5, 0($a0)
		sw $t5, 4($a0)
		sw $t6, 8($a0) # eye coulour
		sw $t5, 12($a0)
		sw $t5, 16($a0)
		
		sw $t8, -4($a0) # prev destroy nose
		sw $t8, -8($a0)
	endfacing:
	sub $a0, $a0, $s4
	sw $t5, 0($a0)
	sw $t5, 4($a0)
	sw $t5, 8($a0)
	sub $a0, $a0, $s4
	sw $t5, 4($a0)
	jr $ra
	
initPads:# called once on init, randomly fills the platforms array
	li $t0, 9 #counter
	ipWhile:
		li $v0, 42  #generates the random number.
		li $a1, 1000  #random num between 0 and 1000
    		syscall
    		li $t1, 4 
    		mult $a0, $t1 # a0 is out actual rng number
    		mflo $t3
    		add $t3, $t3, $s0 # t3 is randomly generated location for our pad
    		
    		mult $t0, $t1 
    		mflo $t4 # array index 
    		add $t4, $t4, $s2 
    		sw $t3, 0($t4)
    		
    		addi $t2, $t0, 10
    		mult $t2, $t1 
    		mflo $t4 # array index 
    		add $t4, $t4, $s2 
    		sw $s0, 0($t4)
    		
    		beqz $t0, ipEnd
    		addi $t0, $t0,  -1
    		j ipWhile
    	ipEnd:
    	
    	addi $t3, $s0, 3648
    	sw $t3, 0($t4)
    	jr $ra
DrawPadAndHitTest: # draws pads from platforms
	addi $sp, $sp, -4
	sw $ra, 0($sp) # push ra on stack
	li $t0, 9 # counter	
	li $t1, 4 
	lw $t7, 12($s1) # last location of doodle
	addi $t7, $t7, -2 # centering factor
	add $t7, $t7, $s4 # minus by 1 row
	lw $s6, 8($s1) # current accel of doodle
	dpfWhile:
    		mult $t0, $t1 
    		mflo $t4 # array index 
    		add $t4, $t4, $s2
    		
    		lw $t4, 0($t4) # t4 has pad coords
    		
    		sub $t6, $t4, $t7
    		abs $t6, $t6 # absolute difference of pad and doodle
    		blt $t6, 14, BounceDoodle # if the distance is close enough, we count is as contact, and bounce # HITBOX
    		j SkipAcc
    		BounceDoodle:
    			blez $s6, SkipAcc
    			
    			addi $sp, $sp, -4
			sw $t4, 0($sp) # push plateform coord on stack
			jal ConvertPixelPosToXY # call converter
			lw $s7, 0($sp) #get y
			addi $sp, $sp, 8 #pop y and x off
        
			sw $s7, 4($s1) # y
			li $s7, -30
			sw $s7, 8($s1) # accel
		SkipAcc:
		
		addi $t2, $t0, 10 #find our past position
    		mult $t2, $t1 
    		mflo $t2 # array index 
    		add $t3, $t2, $s2 
    		lw $t2, 0($t3) 
    		
    		# replace old colours
    		lw $t5, background # color to fill
    		sw $t5, ($t2)
		sw $t5, 4($t2)
		sw $t5, 8($t2)
		sw $t5, 12($t2)
		
		# fill new colours 
    		lw $t5, padGreen # color to fill
		sw $t5, ($t4)
		sw $t5, 4($t4)
		sw $t5, 8($t4)
		sw $t5, 12($t4)
		
		sw $t4, 0($t3) # save prev position
    		
    		dpfWhileEnd:
    		beqz $t0, dpfEnd
    		addi $t0, $t0,  -1    		
    		j dpfWhile
    	dpfEnd:
    	lw $t0, 0($sp) #get ra
	addi $sp, $sp, 4 
	
    	jr $t0



UpdateDoodleVertical: # called to update the doodle position based on velocity
	addi $sp, $sp, -4
	sw $ra, 0($sp) # push ra on stack

	lw $t0, 8($s1) # accell
	lw $t1, 4($s1) # y coord
	
	li $t3, 90 
	div $t3, $t0 # i mod 50
	mfhi $t3  # mod
	beqz $t3, udpdone
	
	bltz $t0 HeadUp
	j HeadDown
	HeadUp:
		ble $t1, 10, scroll
		j goup
		scroll:
			jal ScrollBoard
			lw $t0, 8($s1) # accell
			lw $t1, 4($s1) # y coord
			j udpdone
		goup:
		addi $t1, $t1, -1
        	sw $t1, 4($s1) # go up 
        	
        	j udpdone
	HeadDown:
		addi $t1, $t1, 1
        	sw $t1, 4($s1) # go down
        udpdone:
        
        addi $t0 , $t0 , 1
	sw $t0 , 8($s1) # decrement accell 
        
	lw $ra, 0($sp) #get ra
	addi $sp, $sp, 4 
	
    	jr $ra
	
WipeBoard: # this function fills entire play area with background colour
	   # note: dont run this on every frame
	   
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

ScrollBoard:
	
	addi $sp, $sp, -4
	sw $ra, 0($sp) # push ra on stack
	
	jal UpdateScore
	li $t7, 9 # counter
	li $t1, 4 
	sbWhile:
    		mult $t7, $t1 
    		mflo $t4 # array index 
    		add $t4, $t4, $s2
    		
    		lw $t3, 0($t4) # t3 has pad coords
    		
    		add $t3, $t3, $s4 # add width to pad position to move down by 1
    		
    		# $s4 is 128 
    		addi $t6, $s0, 4500 #  128 * 32
    		bgt $t3, $t6, ResetToTop # if platform is out of range, 
    		j NoResetToTop
    		ResetToTop: # we reset the platform back to top of screen, with random x
    			li $v0, 42  #generates the random number.
			li $a1, 100  #random num between 0 and 100
    			syscall
    			mult $a0, $t1 # a0 is out actual rng number
    			mflo $t3
    			add $t3, $t3, $s0
    		NoResetToTop:
    		
		sw $t3, 0($t4) # save the coord 
		
    		beqz $t7, dpfEnd
    		addi $t7, $t7,  -1
    		j sbWhile
    	sbEnd:

    	lw $ra, 0($sp) #get ra
	addi $sp, $sp, 4 
    	jr $ra

UpdateScore: # update the score 
	addi $sp, $sp, -4
	sw $ra, 0($sp) # push ra on stack
	
	li $t0, 12 # loop index
	
	usFor:
		la $t1, score
		
		add $t1, $t1, $t0 # index
		lw $t3, ($t1) # load element
		
		beq $t3, 9, flipover # flip over to next
		# if not flip over, just increment the score in this index and break
		add $t3, $t3, 1
		sw $t3, ($t1) # save
		j usEndFor # break out 
		flipover:
			li $t3, 0
			sw $t3, ($t1) # set back to 0 and flip over
		
		sub $t0, $t0, 4
		beq $t0, 0, usEndFor
		j usFor
	usEndFor:
	la $t0, score # increment actual score
	lw $t1, 16($t0)
	add $t1, $t1, 1
	sw $t1, 16($t0)
	
	jal IncreaseDiffy
	
	lw $ra, 0($sp) #get ra
	addi $sp, $sp, 4 
    	jr $ra 

DisplayScore:
	li $t0, 0 # loop index
	lw $t5, eyeBlack # color to fill
	lw $t6, background # color to fill
	
	
	dsFor:
		la $t1, score

		li $a1, 4 # index off set 
		mult $t0, $a1 # 32 * index 
		mflo $a1
		add $a1, $a1, $s0 # 32 * index + base address
		add $a1, $a1, 3360 # index
		add $t1, $t1, $t0 # index
		
		lw $t3, ($t1) # load element
	
		beq $t3, 0, Zero
		beq $t3, 1, One
		beq $t3, 2, Two
		beq $t3, 3, Three
		beq $t3, 4, Four
		beq $t3, 5, Five
		beq $t3, 6, Six
		beq $t3, 7, Seven
		beq $t3, 8, Eight
		beq $t3, 9, Nine
		
		dsAfterPrint:
		beq $t0, 12, dsEndFor
		add $t0, $t0, 4
		j dsFor
	dsEndFor:
	jr $ra
	Zero:
		sw $t5, 0($a1)
		sw $t5, 4($a1)
		sw $t5, 8($a1)
		add $a1, $a1, $s4
		sw $t5, 0($a1)
		sw $t6, 4($a1)
		sw $t5, 8($a1)
		add $a1, $a1, $s4
		sw $t5, 0($a1)
		sw $t6, 4($a1)
		sw $t5, 8($a1)
		add $a1, $a1, $s4
    		sw $t5, 0($a1)
		sw $t6, 4($a1)
		sw $t5, 8($a1)
		add $a1, $a1, $s4
    		sw $t5, 0($a1)
		sw $t5, 4($a1)
		sw $t5, 8($a1)
		j dsAfterPrint
	One:
		sw $t5, 0($a1)
		sw $t5, 4($a1)
		sw $t6, 8($a1)
		add $a1, $a1, $s4
		sw $t5, 4($a1)
		sw $t6, 0($a1)
		sw $t6, 8($a1)
		add $a1, $a1, $s4
		sw $t5, 4($a1)
		sw $t6, 0($a1)
		sw $t6, 8($a1)
		add $a1, $a1, $s4
    		sw $t6, 0($a1)
		sw $t5, 4($a1)
		sw $t6, 8($a1)
		add $a1, $a1, $s4
    		sw $t5, 0($a1)
		sw $t5, 4($a1)
		sw $t5, 8($a1)
		j dsAfterPrint
	Two:
		sw $t5, 0($a1)
		sw $t5, 4($a1)
		sw $t5, 8($a1)
		add $a1, $a1, $s4
		sw $t5, 8($a1)
		sw $t6, 4($a1)
		sw $t6, 0($a1)
		add $a1, $a1, $s4
		sw $t5, 4($a1)
		sw $t6, 0($a1)
		sw $t6, 8($a1)
		add $a1, $a1, $s4
    		sw $t5, 0($a1)
		sw $t6, 4($a1)
		sw $t6, 8($a1)
		add $a1, $a1, $s4
    		sw $t5, 0($a1)
		sw $t5, 4($a1)
		sw $t5, 8($a1)
		j dsAfterPrint
	Three:
		sw $t5, 0($a1)
		sw $t5, 4($a1)
		sw $t5, 8($a1)
		add $a1, $a1, $s4
		sw $t5, 8($a1)
		sw $t6, 0($a1)
		sw $t6, 4($a1)
		add $a1, $a1, $s4
		sw $t5, 8($a1)
		sw $t5, 4($a1)
		sw $t6, 0($a1)
		add $a1, $a1, $s4
    		sw $t6, 0($a1)
		sw $t6, 4($a1)
		sw $t5, 8($a1)
		add $a1, $a1, $s4
    		sw $t5, 0($a1)
		sw $t5, 4($a1)
		sw $t5, 8($a1)
		j dsAfterPrint
	Four:
		sw $t5, 8($a1)
		sw $t6, 4($a1)
		sw $t6, 0($a1)
		add $a1, $a1, $s4
		sw $t5, 4($a1)
		sw $t5, 8($a1)
		sw $t6, 0($a1)
		add $a1, $a1, $s4
		sw $t5, 8($a1)
		sw $t6, 4($a1)
		sw $t5, ($a1)
		add $a1, $a1, $s4
		sw $t5, 8($a1)
		sw $t5, 4($a1)
		sw $t5, 0($a1)
		add $a1, $a1, $s4
		sw $t5, 8($a1)
		sw $t6, 4($a1)
		sw $t6, 0($a1)
		j dsAfterPrint
	Five:
		sw $t5, 8($a1)
		sw $t5, 4($a1)
		sw $t5, 0($a1)
		add $a1, $a1, $s4
		sw $t6, 4($a1)
		sw $t5, 0($a1)
		sw $t6, 8($a1)
		add $a1, $a1, $s4
		sw $t5, 8($a1)
		sw $t5, 4($a1)
		sw $t5, 0($a1)
		add $a1, $a1, $s4
		sw $t6, 4($a1)
		sw $t6, 0($a1)
		sw $t5, 8($a1)
		add $a1, $a1, $s4
		sw $t5, 8($a1)
		sw $t5, 4($a1)
		sw $t5, 0($a1)
		j dsAfterPrint
	Six:
		sw $t5, 0($a1)
		sw $t6, 4($a1)
		sw $t6, 8($a1)
		add $a1, $a1, $s4
		sw $t5, 0($a1)
		sw $t6, 4($a1)
		sw $t6, 8($a1)
		add $a1, $a1, $s4
		sw $t5, 0($a1)
		sw $t5, 4($a1)
		sw $t5, 8($a1)
		add $a1, $a1, $s4
		sw $t5, 0($a1)
		sw $t5, 8($a1)
		sw $t6, 4($a1)
		add $a1, $a1, $s4
		sw $t5, 4($a1)
		sw $t5, 0($a1)
		sw $t5, 8($a1)
		j dsAfterPrint
	Seven:
		sw $t5, 0($a1)
		sw $t5, 4($a1)
		sw $t5, 8($a1)
		add $a1, $a1, $s4
		sw $t5, 8($a1)
		sw $t6, 4($a1)
		sw $t6, 0($a1)
		add $a1, $a1, $s4
		sw $t6, 8($a1)
		sw $t5, 4($a1)
		sw $t6, 0($a1)
		add $a1, $a1, $s4
		sw $t6, 8($a1)
		sw $t5, 4($a1)
		sw $t6, 0($a1)
		add $a1, $a1, $s4
		sw $t6, 8($a1)
		sw $t5, 4($a1)
		sw $t6, 0($a1)
		j dsAfterPrint
	Eight:
		sw $t5, 0($a1)
		sw $t5, 8($a1)
		sw $t5, 4($a1)
		add $a1, $a1, $s4
		sw $t5, 8($a1)
		sw $t5, 0($a1)
		sw $t6, 4($a1)
		add $a1, $a1, $s4
		sw $t5, 4($a1)
		sw $t6, 0($a1)
		sw $t6, 8($a1)
		add $a1, $a1, $s4
		sw $t5, 8($a1)
		sw $t5, 0($a1)
		sw $t6, 4($a1)
		add $a1, $a1, $s4
		sw $t5, 8($a1)
		sw $t5, 0($a1)
		sw $t5, 4($a1)
		j dsAfterPrint
	Nine:
		sw $t5, 0($a1)
		sw $t5, 4($a1)
		sw $t5, 8($a1)
		add $a1, $a1, $s4
		sw $t5, 8($a1)
		sw $t5, 0($a1)
		sw $t6, 4($a1)
		add $a1, $a1, $s4
		sw $t5, 0($a1)
		sw $t5, 4($a1)
		sw $t5, 8($a1)
		add $a1, $a1, $s4
		sw $t5, 8($a1)
		sw $t6, 4($a1)
		sw $t6, 0($a1)
		add $a1, $a1, $s4
		sw $t5, 8($a1)
		sw $t6, 4($a1)
		sw $t6, 0($a1)
		j dsAfterPrint

IncreaseDiffy: # increase difficulty
	
	li  $t0, 100 # here we check the score, if its a multiple of 50, we increment the difficulty
	mult $t0, $s3 # scale difficulty increase on current difficulty, space them out
	mflo $t0
	div $t1, $t0 # i mod 50 * difficulty
	
	mfhi $t1  # mod
	bnez $t1, IDend
	
	add $s3, $s3, 1
	bge $s3, 14, min
	
	j IDend
	min:
		li $s3, 14 # max diff is 14 
	IDend:
		jr $ra
Catch:
	lw $t1, 4($s1) # y coord
	bgt $t1, 31, cif
	jr $ra
	cif: 
		j Gameover
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
	
Gameover:
	li $v0, 4
        la $a0, gameover
        syscall 
        
        # show gameover screen
        li $t0, 9
	mult $t0, $s4
	mflo $t0
	add $a1, $s0, $t0 
	add $a1, $a1, 12 #calc starting position for game over 
	jal WipeBoard # remove all from board
	jal PaintGameOver
		
        Endscreen:	
   
        	lw $t0, 0xffff0000 
		beq $t0, 1, IsInput
		j Endscreen
        	IsInput:
			lw $t2, 0xffff0004 # gameover screen, 
			beq $t2, 115, IsS # listen for 's'
			j Endscreen
			IsS:
				la $t0, positionStruct
				li $t1, 56
				sw $t1, 0($t0)
				li $t1, 20
				sw $t1, 4($t0)
				li $t1, -20
				sw $t1, 8($t0)
				
				la $t0, difficulty
				li $t1, 0
				sw $t1, 0($t0)
				j Main
		j Endscreen
		
		
PaintStartGraphic:
	# starting location is a1
	lw $t5, eyeBlack # color to fill
	lw $t6, background # color to fill
	
	
	sw $t5, 0($a1) # 1 row 1 slice
	sw $t5, 4($a1)
	sw $t6, 8($a1)
	
	sw $t6, 12($a1)
	
	sw $t5, 16($a1)
	sw $t5, 20($a1)
	sw $t5, 24($a1)
	
	sw $t6, 28($a1)
	
	sw $t5, 32($a1)
	sw $t5, 36($a1)
	sw $t5, 40($a1)
	
	sw $t6, 44($a1)
		
	sw $t5, 48($a1)
	sw $t5, 52($a1)
	sw $t6, 56($a1)
	
	sw $t6, 60($a1)
	
	sw $t5, 64($a1)
	sw $t6, 68($a1)
	sw $t6, 72($a1)
	
	sw $t6, 76($a1)
	
	sw $t5, 80($a1)
	sw $t5, 84($a1)
	sw $t5, 88($a1)
	
	add $a1, $a1, $s4 # 1row 2 slice
	sw $t5, 0($a1)
	sw $t6, 4($a1)
	sw $t5, 8($a1)
	
	sw $t6, 12($a1)
	
	sw $t5, 16($a1)
	sw $t6, 20($a1)
	sw $t5, 24($a1)
	
	sw $t6, 28($a1)
	
	sw $t5, 32($a1)
	sw $t6, 36($a1)
	sw $t5, 40($a1)
	
	sw $t6, 44($a1)
		
	sw $t5, 48($a1)
	sw $t6, 52($a1)
	sw $t5, 56($a1)
	
	sw $t6, 60($a1)
	
	sw $t5, 64($a1)
	sw $t6, 68($a1)
	sw $t6, 72($a1)
	
	sw $t6, 76($a1)
	
	sw $t5, 80($a1)
	sw $t6, 84($a1)
	sw $t6, 88($a1)
	
	add $a1, $a1, $s4# row 1 slice 3
	sw $t5, 0($a1)
	sw $t6, 4($a1)
	sw $t5, 8($a1)
	
	sw $t6, 12($a1)
	
	sw $t5, 16($a1)
	sw $t6, 20($a1)
	sw $t5, 24($a1)
	
	sw $t6, 28($a1)
	
	sw $t5, 32($a1)
	sw $t6, 36($a1)
	sw $t5, 40($a1)
	
	sw $t6, 44($a1)
		
	sw $t5, 48($a1)
	sw $t6, 52($a1)
	sw $t5, 56($a1)
	
	sw $t6, 60($a1)
	
	sw $t5, 64($a1)
	sw $t6, 68($a1)
	sw $t6, 72($a1)
	
	sw $t6, 76($a1)
	
	sw $t5, 80($a1)
	sw $t5, 84($a1)
	sw $t5, 88($a1)
	
	add $a1, $a1, $s4 # row 1 slice 4
    	sw $t5, 0($a1)
	sw $t6, 4($a1)
	sw $t5, 8($a1)
	
	sw $t5, 0($a1)
	sw $t6, 4($a1)
	sw $t5, 8($a1)
	
	sw $t6, 12($a1)
	
	sw $t5, 16($a1)
	sw $t6, 20($a1)
	sw $t5, 24($a1)
	
	sw $t6, 28($a1)
	
	sw $t5, 32($a1)
	sw $t6, 36($a1)
	sw $t5, 40($a1)
	
	sw $t6, 44($a1)
		
	sw $t5, 48($a1)
	sw $t6, 52($a1)
	sw $t5, 56($a1)
	
	sw $t6, 60($a1)
	
	sw $t5, 64($a1)
	sw $t6, 68($a1)
	sw $t6, 72($a1)
	
	sw $t6, 76($a1)
	
	sw $t5, 80($a1)
	sw $t6, 84($a1)
	sw $t6, 88($a1)
	
	add $a1, $a1, $s4 # row 1 slice 5
    	sw $t5, 0($a1)
	sw $t5, 4($a1)
	sw $t6, 8($a1)
	
	
	sw $t6, 12($a1)
	
	sw $t5, 16($a1)
	sw $t5, 20($a1)
	sw $t5, 24($a1)
	
	sw $t6, 28($a1)
	
	sw $t5, 32($a1)
	sw $t5, 36($a1)
	sw $t5, 40($a1)
	
	sw $t6, 44($a1)
		
	sw $t5, 48($a1)
	sw $t5, 52($a1)
	sw $t6, 56($a1)
	
	sw $t6, 60($a1)
	
	sw $t5, 64($a1)
	sw $t5, 68($a1)
	sw $t5, 72($a1)
	
	sw $t6, 76($a1)
		
	sw $t5, 80($a1)
	sw $t5, 84($a1)
	sw $t5, 88($a1)
	
	li $t0, 3
	mult $t0, $s4
	mflo $t0
	add $a1, $a1, $t0 # new row
	add $a1, $a1, 40

	sw $t5, 0($a1) # 2 row 1 slice
	sw $t5, 4($a1)
	sw $t5, 8($a1)
	
	sw $t6, 12($a1)
	
	sw $t5, 16($a1)
	sw $t6, 20($a1)
	sw $t5, 24($a1)
	
	sw $t6, 28($a1)
	
	sw $t5, 32($a1)
	sw $t6, 36($a1)
	sw $t6, 40($a1)
	sw $t6, 44($a1)
	sw $t5, 48($a1)
	
	sw $t6, 52($a1)
	
	sw $t5, 56($a1)
	sw $t5, 60($a1)
	sw $t5, 64($a1)
	
	add $a1, $a1, $s4
	
	sw $t6, 0($a1) # 2 row 2 slice
	sw $t5, 4($a1)
	sw $t6, 8($a1)
	
	sw $t6, 12($a1)
	
	sw $t5, 16($a1)
	sw $t6, 20($a1)
	sw $t5, 24($a1)
	
	sw $t6, 28($a1)
	
	sw $t5, 32($a1)
	sw $t5, 36($a1)
	sw $t6, 40($a1)
	sw $t5, 44($a1)
	sw $t5, 48($a1)
	
	sw $t6, 52($a1)
	
	sw $t5, 56($a1)
	sw $t6, 60($a1)
	sw $t5, 64($a1)
	
	add $a1, $a1, $s4
	
	sw $t6, 0($a1) # 2 row 3 slice
	sw $t5, 4($a1)
	sw $t6, 8($a1)
	
	sw $t6, 12($a1)
	
	sw $t5, 16($a1)
	sw $t6, 20($a1)
	sw $t5, 24($a1)
	
	sw $t6, 28($a1)
	
	sw $t5, 32($a1)
	sw $t6, 36($a1)
	sw $t5, 40($a1)
	sw $t6, 44($a1)
	sw $t5, 48($a1)
	
	sw $t6, 52($a1)
	
	sw $t5, 56($a1)
	sw $t6, 60($a1)
	sw $t5, 64($a1)
	
	add $a1, $a1, $s4
		
	sw $t6, 0($a1) # 2 row 4 slice
	sw $t5, 4($a1)
	sw $t6, 8($a1)
	
	sw $t6, 12($a1)
	
	sw $t5, 16($a1)
	sw $t6, 20($a1)
	sw $t5, 24($a1)
	
	sw $t6, 28($a1)
	
	sw $t5, 32($a1)
	sw $t6, 36($a1)
	sw $t6, 40($a1)
	sw $t6, 44($a1)
	sw $t5, 48($a1)
	
	sw $t6, 52($a1)
	
	sw $t5, 56($a1)
	sw $t5, 60($a1)
	sw $t5, 64($a1)
	
	add $a1, $a1, $s4
		
	sw $t5, 0($a1) # 2 row 4 slice
	sw $t5, 4($a1)
	sw $t6, 8($a1)
	
	sw $t6, 12($a1)
	
	sw $t5, 16($a1)
	sw $t5, 20($a1)
	sw $t5, 24($a1)
	
	sw $t6, 28($a1)
	
	sw $t5, 32($a1)
	sw $t6, 36($a1)
	sw $t6, 40($a1)
	sw $t6, 44($a1)
	sw $t5, 48($a1)
	
	sw $t6, 52($a1)
	
	sw $t5, 56($a1)
	sw $t6, 60($a1)
	sw $t6, 64($a1)
	
	jr $ra
	
	
PaintGameOver:
	# starting location is a1
	lw $t5, eyeBlack # color to fill
	lw $t6, background # color to fill
	
	sw $t5, 0($a1) # 1 row 1 slice
	sw $t5, 4($a1)
	sw $t5, 8($a1)
	sw $t5, 12($a1)
	
	sw $t6, 16($a1)
	
	sw $t5, 20($a1)
	sw $t5, 24($a1)
	sw $t5, 28($a1)
	
	sw $t6, 32($a1)
	
	sw $t5, 36($a1)
	sw $t6, 40($a1)
	sw $t6, 44($a1)
	sw $t6, 48($a1)
	sw $t5, 52($a1)
	
	sw $t6, 56($a1)
	
	sw $t5, 60($a1)
	sw $t5, 64($a1)
	sw $t5, 68($a1)
	
	add $a1, $a1, $s4
		
	sw $t5, 0($a1) # 1 row 2 slice
	sw $t6, 4($a1)
	sw $t6, 8($a1)
	sw $t6, 12($a1)
	
	sw $t6, 16($a1)
	
	sw $t5, 20($a1)
	sw $t6, 24($a1)
	sw $t5, 28($a1)
	
	sw $t6, 32($a1)
	
	sw $t5, 36($a1)
	sw $t5, 40($a1)
	sw $t6, 44($a1)
	sw $t5, 48($a1)
	sw $t5, 52($a1)
	
	sw $t6, 56($a1)
	
	sw $t5, 60($a1)
	sw $t6, 64($a1)
	sw $t6, 68($a1)
	add $a1, $a1, $s4
		
	sw $t5, 0($a1) # 1 row 3 slice
	sw $t6, 4($a1)
	sw $t5, 8($a1)
	sw $t5, 12($a1)
	
	sw $t6, 16($a1)
	
	sw $t5, 20($a1)
	sw $t5, 24($a1)
	sw $t5, 28($a1)
	
	sw $t6, 32($a1)
	
	sw $t5, 36($a1)
	sw $t6, 40($a1)
	sw $t5, 44($a1)
	sw $t6, 48($a1)
	sw $t5, 52($a1)
	
	sw $t6, 56($a1)
	
	sw $t5, 60($a1)
	sw $t5, 64($a1)
	sw $t5, 68($a1)
	add $a1, $a1, $s4
		
	sw $t5, 0($a1) # 1 row 4 slice
	sw $t6, 4($a1)
	sw $t6, 8($a1)
	sw $t5, 12($a1)
	
	sw $t6, 16($a1)
	
	sw $t5, 20($a1)
	sw $t6, 24($a1)
	sw $t5, 28($a1)
	
	sw $t6, 32($a1)
	
	sw $t5, 36($a1)
	sw $t6, 40($a1)
	sw $t6, 44($a1)
	sw $t6, 48($a1)
	sw $t5, 52($a1)
	
	sw $t6, 56($a1)
	
	sw $t5, 60($a1)
	sw $t6, 64($a1)
	sw $t6, 68($a1)
	add $a1, $a1, $s4
		
	sw $t5, 0($a1) # 1 row 5 slice
	sw $t5, 4($a1)
	sw $t5, 8($a1)
	sw $t5, 12($a1)
	
	sw $t6, 16($a1)
	
	sw $t5, 20($a1)
	sw $t6, 24($a1)
	sw $t5, 28($a1)
	
	sw $t6, 32($a1)
	
	sw $t5, 36($a1)
	sw $t6, 40($a1)
	sw $t6, 44($a1)
	sw $t6, 48($a1)
	sw $t5, 52($a1)
	
	sw $t6, 56($a1)
	
	sw $t5, 60($a1)
	sw $t5, 64($a1)
	sw $t5, 68($a1)
	
	li $t0, 3
	mult $t0, $s4
	mflo $t0
	add $a1, $a1, $t0 # new row
	add $a1, $a1, 40
		
	sw $t5, 0($a1) # 2 row 1 slice
	sw $t5, 4($a1)
	sw $t5, 8($a1)
	
	sw $t6, 12($a1)
	
	sw $t5, 16($a1)
	sw $t6, 20($a1)
	sw $t5, 24($a1)
	
	sw $t6, 28($a1)
	
	sw $t5, 32($a1)
	sw $t5, 36($a1)
	sw $t5, 40($a1)
	
	sw $t6, 44($a1)
	
	sw $t5, 48($a1)
	sw $t5, 52($a1)
	sw $t5, 56($a1)
	
	add $a1, $a1, $s4
	sw $t5, 0($a1) # 2 row 2 slice
	sw $t6, 4($a1)
	sw $t5, 8($a1)
	
	sw $t6, 12($a1)
	
	sw $t5, 16($a1)
	sw $t6, 20($a1)
	sw $t5, 24($a1)
	
	sw $t6, 28($a1)
	
	sw $t5, 32($a1)
	sw $t6, 36($a1)
	sw $t6, 40($a1)
	
	sw $t6, 44($a1)
	
	sw $t5, 48($a1)
	sw $t6, 52($a1)
	sw $t5, 56($a1)
	
	add $a1, $a1, $s4
	sw $t5, 0($a1) # 2 row 3 slice
	sw $t6, 4($a1)
	sw $t5, 8($a1)
	
	sw $t6, 12($a1)
	
	sw $t5, 16($a1)
	sw $t6, 20($a1)
	sw $t5, 24($a1)
	
	sw $t6, 28($a1)
	
	sw $t5, 32($a1)
	sw $t5, 36($a1)
	sw $t5, 40($a1)
	
	sw $t6, 44($a1)
	
	sw $t5, 48($a1)
	sw $t5, 52($a1)
	sw $t6, 56($a1)
	
	add $a1, $a1, $s4
	sw $t5, 0($a1) # 2 row 4 slice
	sw $t6, 4($a1)
	sw $t5, 8($a1)
	
	sw $t6, 12($a1)
	
	sw $t5, 16($a1)
	sw $t6, 20($a1)
	sw $t5, 24($a1)
	
	sw $t6, 28($a1)
	
	sw $t5, 32($a1)
	sw $t6, 36($a1)
	sw $t6, 40($a1)
	
	sw $t6, 44($a1)
	
	sw $t5, 48($a1)
	sw $t6, 52($a1)
	sw $t5, 56($a1)
	
	add $a1, $a1, $s4
	sw $t5, 0($a1) # 2 row 4 slice
	sw $t5, 4($a1)
	sw $t5, 8($a1)
	
	sw $t6, 12($a1)
	
	sw $t6, 16($a1)
	sw $t5, 20($a1)
	sw $t6, 24($a1)
	
	sw $t6, 28($a1)
	
	sw $t5, 32($a1)
	sw $t5, 36($a1)
	sw $t5, 40($a1)
	
	sw $t6, 44($a1)
	
	sw $t5, 48($a1)
	sw $t6, 52($a1)
	sw $t5, 56($a1)
	
	jr $ra
Exit:
	li $v0, 10 # terminate the program gracefully
	syscall

    
