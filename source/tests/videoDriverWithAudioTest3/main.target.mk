SOURCE_FILES := \
	tests/videoDriverWithAudioTest3/main.c \
	tests/videoDriverWithAudioTest3/writeScreen.s \
	tests/videoDriverWithAudioTest3/tileMap.c \
	tests/videoDriverWithAudioTest3/lcd.c
COMPILER_FLAGS := -Wall -Os -flto -DTILE_WIDTH=8
MCU := atmega644p
F_CPU := 12000000
