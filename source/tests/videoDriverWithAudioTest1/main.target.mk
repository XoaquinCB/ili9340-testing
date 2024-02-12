SOURCE_FILES := \
	tests/videoDriverWithAudioTest1/main.c \
	tests/videoDriverWithAudioTest1/writeScreen.s \
	tests/videoDriverWithAudioTest1/tileMap.c \
	tests/videoDriverWithAudioTest1/lcd.c
COMPILER_FLAGS := -Wall -Os -flto -DTILE_WIDTH=6
MCU := atmega644p
F_CPU := 12000000
