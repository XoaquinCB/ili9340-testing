SOURCE_FILES := \
	tests/videoDriverWithAudioTest2/main.c \
	tests/videoDriverWithAudioTest2/writeScreen.s \
	tests/videoDriverWithAudioTest2/tileMap.c \
	tests/videoDriverWithAudioTest2/lcd.c
COMPILER_FLAGS := -Wall -Os -flto -DTILE_WIDTH=6
MCU := atmega644p
F_CPU := 12000000
