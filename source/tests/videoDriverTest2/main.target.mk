SOURCE_FILES := \
	tests/videoDriverTest2/main.c \
	tests/videoDriverTest2/writeScreenNoInterrupts.s \
	tests/videoDriverTest2/tileMap.c
COMPILER_FLAGS := -Wall -Os -flto -DTILE_WIDTH=6
MCU := atmega644p
F_CPU := 12000000
