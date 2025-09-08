#ifndef ODIFF_IO_H
#define ODIFF_IO_H

#include <stdint.h>
#include <stdlib.h>

typedef struct {
  int width;
  int height;
  uint32_t *data;
} ImageData;

ImageData read_png_file(const char *filename,
                        /* std.mem.Allocator */ void *allocator);
ImageData read_jpg_file(const char *filename,
                        /* std.mem.Allocator */ void *allocator);
ImageData read_tiff_file(const char *filename,
                         /* std.mem.Allocator */ void *allocator);
ImageData read_bmp_file(const char *filename, void *allocator);

int write_png_file(const char *filename, int width, int height,
                   const uint32_t *data);

// Hook to use zig's allocator for image data
// probably either to just rewrite all the functions in zig
void free_image_data_ptr(uint32_t *data,
                         /* std.mem.Allocator */ void *allocator, size_t size);
void *zig_alloc(/* std.mem.Allocator */ void *allocator, size_t size);
void zig_free(/* std.mem.Allocator */ void *allocator, void *ptr, size_t size);

#endif
