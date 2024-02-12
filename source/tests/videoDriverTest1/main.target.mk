SOURCE_FILES := \
	tests/videoDriverTest1/main.c \
	tests/videoDriverTest1/writeScreenNoInterrupts.s \
	tests/videoDriverTest1/tileMap.c
COMPILER_FLAGS := -Wall -Os -flto
MCU := atmega644p
F_CPU := 12000000
