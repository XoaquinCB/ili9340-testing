SOURCE_FILES := \
	tests/videoDriverWithAudioDoubleScanlineTest1/main.c \
	tests/videoDriverWithAudioDoubleScanlineTest1/writeScreen.s \
	tests/videoDriverWithAudioDoubleScanlineTest1/tileMap.c \
	tests/videoDriverWithAudioDoubleScanlineTest1/lcd.c
COMPILER_FLAGS := -Wall -Os -flto -DTILE_WIDTH=8
MCU := atmega644p
F_CPU := 12000000
