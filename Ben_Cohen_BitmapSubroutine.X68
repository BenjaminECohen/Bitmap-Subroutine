*-----------------------------------------------------------
* Title      : Bitmap Subroutine
* Written by : Ben Cohen    
* Date       : 9/25/2023
* Description: Bit mapping dawg
*-----------------------------------------------------------
    
    
    
    
    
    ;USER!!!!! ARGUMENTS FOR SUBROUTINE DrawBMP
    ;a0 = Pointer to bmp file
    ;d2 = Left,Top Corner of bitmap chunk => High.w = Left, Low.W = Top
    ;d3 = Width/Height of bitmap chunk => High.w = Width, Low.W = Height
    ;d4 = Left,Top Corner of output display to display bitmap chunk => High.w = Left, Low.w = Top
    
    
    ;NOTE: If chunk offset is at a width/height that exceeds the BMP, offset will be set to 0, respectively
    ;NOTE: If Chunk Size is larger in width and/or height, chunk size will be set to the respective max value of the BMP minus the chunk offset
    ;NOTE: Having all inputs be 0, in accordance, will result in printing the entire BMP
    
    
Full_Image_Width    EQU     0
Full_Image_Height   EQU     2
Chunk_X_Offset      EQU     4
Chunk_Y_Offset      EQU     6
Chunk_Width         EQU     8
Chunk_Height        EQU     10
Output_X_Pos        EQU     12
Output_Y_Pos        EQU     14

BITMAP_IMAGE_DATA_OFFSET    EQU     10
BITMAP_WIDTH_OFFSET         EQU     18
BITMAP_HEIGHT_OFFSET        EQU     22
BITMAP_BPP_OFFSET           EQU     28


DrawBMP:

    move.l  a0,a2                      ;For getting width and height
    move.l  d4,d0                       ;Save user input here for now
    
    cmp.w   #$424D,(a0)                   ;Check to see if file is BMP
    BNE     EndNotBMP
    
    cmp.b   #32,BITMAP_BPP_OFFSET(a0)     ;Check to see if BMP is 32-bit
    BNE     EndNot32Bit
    
    move.l  BITMAP_WIDTH_OFFSET(a0),d4                  ;width   
    jsr     ConvertToBigEndian
    move.l  d4,d6
    cmp.l   #0,d6
    BEQ     End                         ;MAke sure image width isnt zero
    
    move.l  BITMAP_HEIGHT_OFFSET(a0),d4                   ;Height
    jsr     ConvertToBigEndian
    move.l  d4,d7  
    cmp.l   #0,d7
    BEQ     End                         ;Make sure image height isnt zero
    
    move.l  d0,d4                       ;Move user input back into d4 UNCOMMENT IF NEEDED
    
    
    ;Get d1 to store max image size
    clr.l   d1
    move.w  d6,d1
    swap    d1
    move.w  d7,d1
    
    movem.l D1-D4,-(sp)                 ;Move vals to stack then 
    
    ;Check that offset does not extend past max image size (does it? Set to 0)
    clr.l   d1
    clr.l   d4

CheckForZeroChunkX:

    cmp.w   #0,Chunk_Width(sp)
    BNE     CheckForZeroChunkY
    move.w  Full_Image_Width(sp),Chunk_Width(sp)
    
CheckForZeroChunkY:
    cmp.w   #0,Chunk_Height(sp)
    BNE     CheckChunkXOffset
    move.w  Full_Image_Height(sp),Chunk_Height(sp)


CheckChunkXOffset:
    
    move.w  Full_Image_Width(sp),d1
    move.w  Chunk_X_Offset(sp),d4
    cmp.l   d4,d1
    BGT     CheckChunkYOffset

    move.w  #0,Chunk_X_Offset(sp)

CheckChunkYOffset:

    move.w  Full_Image_Height(sp),d1
    move.w  Chunk_Y_Offset(sp),d4
    cmp.l   d4,d1
    BGT     CheckWidth

    move.w  #0,Chunk_Y_Offset(sp)
    
CheckWidth:    
    ;Check that chunk size is not larger than picture    
    move.w  Full_Image_Width(sp),d1
    sub.w   Chunk_X_Offset(sp),d1    
    move.w  Chunk_Width(sp),d4
    cmp.l   d4,d1
    
    BGE     CheckHeight
    
    move.w  d1,Chunk_Width(sp)  ;Set max size minus offset as chunk size
        
CheckHeight:

    move.w  Full_Image_Height(sp),d1
    sub.w   Chunk_Y_Offset(sp),d1
    move.w  Chunk_Height(sp),d4
    cmp.l   d4,d1
    BGE     SetOutputScreen
    
    move.w  d1,Chunk_Height(sp)  ;Set max size minus offset as chunk size


SetOutputScreen:
    
    ;SETTING OUTPUT SCREEN SIZE TO DISPLAY JUST ENOUGH   
    clr.l   d1
    move.w  Output_X_Pos(sp),d1
    add.w   Chunk_Width(sp),d1
    swap    d1
    move.w  Output_Y_Pos(sp),d1
    add.w   Chunk_Height(sp),d1
    
    move.l  #33,d0
    ;TRAP    #15
    
   
    

    move.l  a0,a1
    move.b  BITMAP_IMAGE_DATA_OFFSET(a0),d0
    add.l   d0,a1                               ;Move image data start to a1 address
    
    
    ;clear iterator registers
    clr.l   d6
    clr.l   d7
    
    move.w  Chunk_Height(sp),d7         ;Set max height of chunk
    
    
    ;d0 store x and d1 store y of chunk start
    clr.l   d0
    clr.l   d1
    clr.l   d3
    
    ;To Find the actual height for d7
    
    move.w  Full_Image_Height(sp),d1    ;Move max image height to d1
    sub.w   Chunk_Y_Offset(sp),d1       ;remove chunk offset from d1
    sub.w   Chunk_Height(sp),d1         ;remove chunk height size from d1

    
    mulu.w  Full_Image_Width(sp),d1     ;multiply max width by true height and assign to d1
    lsl.l   #02,d1                      ;Multiple by 4 to get from long to bytes (shift left 2 bits is the same)   
    add.l   d1,a1                       ;add height(y) offset to a1
    move.l  a1,a3                       ;store start of data to a3 and a3 will increment by width + offset when called
    
    clr.l   d1
    move.w  Chunk_X_Offset(sp),d1       ;get x offset
    mulu.w  #04,d1                      ;get x offset bytes
    add.l   d1,a1                       ;added the offset to a1
    move.l  sp,a2                       ;save current stack pointer to a2
    

BasicDraw:
    
    
    move.l  (a1)+,d4                    ;Get pixel data at a1 then increment
    
    jsr     ConvertToBGR
  
    move.l  d4,d1                       ;Set Pen Color
    move.l  #80,d0
    TRAP #15
    
    ;color pixel (requires output coordinate mapping)
    move.l  d6,d1                       ;move current x val to output x
    add.w   Output_X_Pos(sp),d1             ;add in the user define output offset for X
    move.l  d7,d2                       ;move current y val to output y
    add.w   Output_Y_Pos(sp),d2             ;add the user defined output offset for Y
    sub.w   #01,d2                      ;Minus 1 to output to account for max size
    move.l  #82,d0
    TRAP #15
    
    ;increment width iterator value
    add.l   #01,d6
    
    clr.l   d1
    move.w  Chunk_Width(sp),d1      ;Move chunk width to d1
    cmp.l   d1,d6                   ;We at width of chunk?
    BNE     BasicDraw
    
    
CheckIfEnd:
    clr.l   d1
    cmp.l   d1,d7       ;If the height = 0, we are done since current height = final height of chunk
    BEQ     End
    jsr     NextRow
    BNE     BasicDraw   ;Branch to draw again
    
End:  
    movem.l (sp)+,D1-D4
    rts
    
EndNotBMP:
    ;Print not a bmp to screen
    move.l  #13,d0
    lea     NotBMP,a1
    TRAP #15
    rts
    
EndNot32Bit:
    ;Print not 32 bit to screen
    move.l  #13,d0
    lea     Not32Bit,a1
    TRAP #15
    rts


NextRow:
    clr.l   d6
    clr.l   d1
    clr.l   d2
    
    add.l   #01,d3                      ;REMOVE LATER IF NOT USED
    
    ;go to next row offset
    move.w  Full_Image_Width(a2),d1     ;Move full image width to d1
    lsl.l   #02,d1                      ;Multiple by 4 to get from long to bytes  
    add.l   d1,a3                       ;add this increment to a3 (the row holder)   
    move.l  a3,a1                       ;give increment to a1
    
    move.w  Chunk_X_Offset(a2),d2       ;add width offset (long) to d2
    mulu.w   #04,d2                     ;get width offset in bytes
    add.l   d2,a1                       ;add to a1    
    sub.l   #01,d7                      ;decrease current height count
    rts
    
ConvertToBigEndian:

    
    move.b  d4,d5
    lsr.l   #$08,d4
    lsl.l   #$08,d5
    move.b  d4,d5
    lsr.l   #$08,d4
    lsl.l   #$08,d5
    move.b  d4,d5
    lsr.l   #$08,d4
    lsl.l   #$08,d5
    move.b  d4,d5
    move.l  d5,d4
    rts
    
ConvertToBGR:   

    move.b  d4,d5
    lsr.l   #$08,d4
    swap    d5
    lsl.l   #$08,d5
    add.l  d5,d4
    
    rts
    
        
   
NotBMP  dc.b    'File not a Bitmap',0
Not32Bit    dc.b    'BMP is not in 32-bit format',0


;END OF DrawBMP Subroutine


        STOP    #$1000
   
START   ORG    $2000                  ; first instruction of program

* Put program code here
    
    
    ;TESTING CASES
    
    ;Chunk Offset
    ;move.l  #$00FA01C2,d2   ;Bitmap chunk start at 250,450
    ;move.l  #$00000000,d2   ;Bitmap chunk start at 0,0
    ;move.l  #$006400C8,d2   ;Bitmap chunk start at 100,200
    ;move.l  #$00320048,d2   ;Bitmap chunk start at 50,75
    ;move.l  #$FFFFFFFF,d2    ;Bitmap chunk start at Max,Max
    
    lea     Bitmap, a0
    
    jsr DrawBMP
    
    lea     Bitmap, a0
    move.l  #$00FA01C2,d2   ;Bitmap chunk start at 250,450
    move.l  #$00C8012C,d3   ;Chunk 200x300
    
    jsr DrawBMP
    
    
    lea     Bitmap, a0
    move.l  #$006400C8,d2   ;Bitmap chunk start at 100,200
    move.l  #$00640064,d3   ;Chunk 100x100
    move.l  #$006400FA,d4   ;Output at 100,250

    jsr DrawBMP
    
    
    
    ;Chunk Size
    ;move.l  #$00C8012C,d3   ;Chunk 200x300
    ;move.l  #$00640064,d3   ;Chunk 100x100
    ;move.l #$023A038F,d3    ;Chunk 570x911 W bmp size
    ;move.l  #$00D800F8,d3   ;Chunk 216x248 chen transparent size
    ;move.l  #$015E0190,d3   ;Chunk 350x400
    ;move.l  #$FFFFFFFF,d3   ;Max chunk possible
    
    ;Height chunk test
    ;move.l  #$000001c2,d2      ;Chunk bitmap chunk start at 0,450
    ;move.l  d1,d3
    ;move.w  #$012C,d3      ;Chunk height = 300
    
    ;side chunk test
    ;move.l  d1,d3
    ;swap    d3
    ;move.w  #$00C8, d3      ;Chunk is max height, but certain width
    ;swap    d3
    
    ;Output Offset Test
    ;move.l  #$006400FA,d4   ;Output at 100,250
    ;move.l  #$019601AF,d4   ;Output at 406,431
    ;clr.l   d4              ;Output at 0,0
    
    
    lea     Bitmap, a0
    
    jsr DrawBMP

    move.l  #$0,d0
    
  
    
    
    
    

    




        STOP #$2000
* Put variables and constants here


Bitmap:  
    INCBIN  "w copy.bmp"    
    ;INCBIN  "chen_transparent.bmp"
    ;INCBIN  "asmdata.bin"
    ;INCBIN  "mario_face.bmp"
 

    END    START        ; last line of source














*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
