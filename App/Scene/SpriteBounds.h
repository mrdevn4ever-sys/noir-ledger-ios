#ifndef NOIR_SPRITE_BOUNDS_H
#define NOIR_SPRITE_BOUNDS_H

#include <stddef.h>
#include <stdint.h>

typedef struct {
    size_t x, y, width, height;
} NoirSpriteBounds;

// Union in frame-local pixels, with two pixels of filtering margin. Input is tightly packed BGRA.
NoirSpriteBounds NoirTrimBGRA(const uint8_t *pixels, size_t width, size_t height, size_t frameWidth);

#endif
