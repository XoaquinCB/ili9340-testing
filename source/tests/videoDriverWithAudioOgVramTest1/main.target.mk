SOURCE_FILES := \
	tests/videoDriverWithAudioOgVramTest1/main.c \
	tests/videoDriverWithAudioOgVramTest1/writeScreen.s \
	tests/videoDriverWithAudioOgVramTest1/tileMap.c \
	tests/videoDriverWithAudioOgVramTest1/lcd.c
COMPILER_FLAGS := -Wall -Os -flto -DTILE_WIDTH=6
MCU := atmega644p
F_CPU := 12000000
