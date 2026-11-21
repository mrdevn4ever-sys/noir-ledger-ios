#include "SpriteBounds.h"

// Check only the outside edges: no pixel inside the current horizontal span can widen the crop.
// Vertical extents are found separately so opaque sheets can stop after their four edges.
static int occupied(const uint8_t *row, size_t width) {
    for (size_t x = 0; x < width; ++x) {
        if (row[x * 4 + 3] > 2) return 1;
    }
    return 0;
}

NoirSpriteBounds NoirTrimBGRA(const uint8_t *pixels, size_t width, size_t height, size_t frameWidth) {
    if (!pixels || !frameWidth || !height || frameWidth > width || width > SIZE_MAX / 4 / height) {
        return (NoirSpriteBounds){0, 0, 0, 0};
    }
    size_t stride = width * 4;
    size_t top = 0, bottom = height;
    while (top < bottom && !occupied(pixels + top * stride, width)) ++top;
    if (top == bottom) return (NoirSpriteBounds){0, 0, frameWidth, height};
    while (!occupied(pixels + (bottom - 1) * stride, width)) --bottom;

    size_t left = frameWidth, right = 0;
    for (size_t y = top; y < bottom && (left != 0 || right != frameWidth); ++y) {
        const uint8_t *row = pixels + y * stride;
        for (size_t start = 0; start < width; start += frameWidth) {
            // A partial trailing frame contributes to the union just like x % frameWidth.
            size_t n = width - start < frameWidth ? width - start : frameWidth;
            const uint8_t *frame = row + start * 4;
            for (size_t x = 0; x < left && x < n; ++x) {
                if (frame[x * 4 + 3] > 2) { left = x; break; }
            }
            for (size_t x = n; x > right; --x) {
                if (frame[(x - 1) * 4 + 3] > 2) { right = x; break; }
            }
            if (left == 0 && right == frameWidth) break;
        }
    }
    left = left > 2 ? left - 2 : 0;
    right = frameWidth - right > 2 ? right + 2 : frameWidth;
    top = top > 2 ? top - 2 : 0;
    bottom = height - bottom > 2 ? bottom + 2 : height;
    return (NoirSpriteBounds){left, top, right - left, bottom - top};
}
