
#ifndef _NOPSYS_CONSOLE_H_
#define _NOPSYS_CONSOLE_H_

#include "types.h"

#define CONSOLE_TEXT_BUFFER_SIZE 1000*1000

typedef struct text_pen_t
{
	int positionX;
	int positionY;
	
	int width;
	int glyph_width;
	int glyph_height;

	display_info_t *display;
	
} text_pen_t;

typedef struct console_t
{
	int glyph_width;
	int glyph_height;
	
	int width;
	int height;
	
	char text[CONSOLE_TEXT_BUFFER_SIZE];
	int text_size;
	
	bool debugging_now;

} console_t;


#endif  // _NOPSYS_CONSOLE_H_
