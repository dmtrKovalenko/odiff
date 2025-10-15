#ifdef __linux__
#define _GNU_SOURCE
#endif

#include "odiff_io.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if defined(HAVE_JPEG)
#include <jpeglib.h>
#endif
#if defined(HAVE_SPNG)
#include <spng.h>
#endif
#if defined(HAVE_TIFF)
#include <tiffio.h>
#endif
#if defined(HAVE_WEBP)
#include <webp/decode.h>
#endif

#ifdef _WIN32
#include <io.h>
#include <windows.h>
#else
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#endif

// Cross-platform file buffer for memory mapping
typedef struct {
  void *data;
  size_t size;
#ifdef _WIN32
  HANDLE hFile;
  HANDLE hMapping;
#else
  int fd;
#endif
} FileBuffer;

// Initialize file buffer with memory mapping
static FileBuffer open_file_buffer(const char *filename) {
  FileBuffer buffer = {0};

#ifdef _WIN32
  buffer.hFile = CreateFileA(filename, GENERIC_READ, FILE_SHARE_READ, NULL,
                             OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
  if (buffer.hFile == INVALID_HANDLE_VALUE)
    return buffer;

  LARGE_INTEGER file_size;
  if (!GetFileSizeEx(buffer.hFile, &file_size) || file_size.QuadPart == 0) {
    CloseHandle(buffer.hFile);
    buffer.hFile = INVALID_HANDLE_VALUE;
    return buffer;
  }

  buffer.hMapping =
      CreateFileMappingA(buffer.hFile, NULL, PAGE_READONLY, 0, 0, NULL);
  if (!buffer.hMapping) {
    CloseHandle(buffer.hFile);
    buffer.hFile = INVALID_HANDLE_VALUE;
    return buffer;
  }

  buffer.data = MapViewOfFile(buffer.hMapping, FILE_MAP_READ, 0, 0, 0);
  if (!buffer.data) {
    CloseHandle(buffer.hMapping);
    CloseHandle(buffer.hFile);
    buffer.hFile = INVALID_HANDLE_VALUE;
    return buffer;
  }

  buffer.size = (size_t)file_size.QuadPart;

#else
  buffer.fd = open(filename, O_RDONLY);
  if (buffer.fd == -1)
    return buffer;

  struct stat st;
  if (fstat(buffer.fd, &st) == -1 || st.st_size <= 0) {
    close(buffer.fd);
    buffer.fd = -1;
    return buffer;
  }

  buffer.data = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, buffer.fd, 0);
  if (buffer.data == MAP_FAILED) {
    close(buffer.fd);
    buffer.fd = -1;
    buffer.data = NULL;
    return buffer;
  }

#ifdef MADV_SEQUENTIAL
  madvise(buffer.data, st.st_size, MADV_SEQUENTIAL);
#endif
  buffer.size = st.st_size;
#endif

  return buffer;
}

// Cleanup file buffer
static void close_file_buffer(FileBuffer *buffer) {
  if (!buffer)
    return;

#ifdef _WIN32
  if (buffer->data) {
    UnmapViewOfFile(buffer->data);
    buffer->data = NULL;
  }
  if (buffer->hMapping) {
    CloseHandle(buffer->hMapping);
    buffer->hMapping = NULL;
  }
  if (buffer->hFile != INVALID_HANDLE_VALUE) {
    CloseHandle(buffer->hFile);
    buffer->hFile = INVALID_HANDLE_VALUE;
  }
#else
  if (buffer->data && buffer->data != MAP_FAILED) {
    munmap(buffer->data, buffer->size);
    buffer->data = NULL;
  }
  if (buffer->fd != -1) {
    close(buffer->fd);
    buffer->fd = -1;
  }
#endif
  buffer->size = 0;
}

ImageData read_png_file(const char *filename, void *allocator) {
#if defined(HAVE_SPNG)
  ImageData result = {0, 0, NULL};

  // Memory-map the PNG file (cross-platform)
  FileBuffer file_buf = open_file_buffer(filename);
  if (!file_buf.data)
    return result;

  spng_ctx *ctx = spng_ctx_new(0);
  if (ctx == NULL) {
    close_file_buffer(&file_buf);
    return result;
  }

  // Ignore and don't calculate chunk CRC's for better performance
  spng_set_crc_action(ctx, SPNG_CRC_USE, SPNG_CRC_USE);

  // Set memory usage limits
  size_t limit = 1024 * 1024 * 64;
  spng_set_chunk_limits(ctx, limit, limit);

  // Set source PNG from memory-mapped data
  int spng_result = spng_set_png_buffer(ctx, file_buf.data, file_buf.size);
  if (spng_result) {
    spng_ctx_free(ctx);
    close_file_buffer(&file_buf);
    return result;
  }

  struct spng_ihdr ihdr;
  spng_result = spng_get_ihdr(ctx, &ihdr);
  if (spng_result) {
    spng_ctx_free(ctx);
    close_file_buffer(&file_buf);
    return result;
  }

  size_t out_size;
  spng_result = spng_decoded_image_size(ctx, SPNG_FMT_RGBA8, &out_size);
  if (spng_result) {
    spng_ctx_free(ctx);
    close_file_buffer(&file_buf);
    return result;
  }

  result.width = ihdr.width;
  result.height = ihdr.height;
  result.data = (uint32_t *)zig_alloc(allocator, ihdr.width * ihdr.height *
                                                     sizeof(uint32_t));
  if (!result.data) {
    spng_ctx_free(ctx);
    close_file_buffer(&file_buf);
    return result;
  }

  spng_result = spng_decode_image(ctx, result.data, out_size, SPNG_FMT_RGBA8,
                                  SPNG_DECODE_TRNS);
  if (spng_result) {
    zig_free(allocator, result.data,
             ihdr.width * ihdr.height * sizeof(uint32_t));
    result.data = NULL;
    spng_ctx_free(ctx);
    close_file_buffer(&file_buf);
    return result;
  }

  spng_ctx_free(ctx);
  close_file_buffer(&file_buf);
  return result;
#else
  fprintf(stderr, "SPNG support not enabled\n");
  abort();
#endif
}

int write_png_file(const char *filename, int width, int height,
                   const uint32_t *data) {
#if defined(HAVE_SPNG)
  FILE *fp = fopen(filename, "wb");
  if (fp == NULL) {
    fprintf(stderr, "Failed to open file for writing: %s\n", filename);
    return -1;
  }

  spng_ctx *ctx = spng_ctx_new(SPNG_CTX_ENCODER);
  if (ctx == NULL) {
    fclose(fp);
    return -1;
  }

  struct spng_ihdr ihdr = {
      .width = width,
      .height = height,
      .bit_depth = 8,
      .color_type = SPNG_COLOR_TYPE_TRUECOLOR_ALPHA,
      .compression_method = 0,
      .filter_method = SPNG_FILTER_NONE,
      .interlace_method = SPNG_INTERLACE_NONE,
  };

  int result = spng_set_ihdr(ctx, &ihdr);
  if (result) {
    fprintf(stderr, "spng_set_ihdr failed: %s\n", spng_strerror(result));
    spng_ctx_free(ctx);
    fclose(fp);
    return -1;
  }

  result = spng_set_option(ctx, SPNG_FILTER_CHOICE, SPNG_DISABLE_FILTERING);
  if (result) {
    spng_ctx_free(ctx);
    fclose(fp);
    return -1;
  }

  result = spng_set_png_file(ctx, fp);
  if (result) {
    spng_ctx_free(ctx);
    fclose(fp);
    return -1;
  }

  // Start progressive encoding - use SPNG_FMT_PNG like the original odiff
  result = spng_encode_image(ctx, 0, 0, SPNG_FMT_PNG, SPNG_ENCODE_PROGRESSIVE);
  if (result) {
    fprintf(stderr, "spng_encode_image (start) failed: %s\n",
            spng_strerror(result));
    spng_ctx_free(ctx);
    fclose(fp);
    return -1;
  }

  // Encode scanlines - pass data directly like original odiff
  size_t bytes_per_row = width * 4; // 4 bytes per pixel (RGBA)
  const char *byte_data = (const char *)data;

  for (int i = 0; i < height; i++) {
    const char *row = byte_data + bytes_per_row * i;
    result = spng_encode_scanline(ctx, row, bytes_per_row);
    if (result)
      break;
  }

  // Check if encoding completed successfully (SPNG_EOI means end of image -
  // success)
  if (result != SPNG_EOI) {
    fprintf(stderr, "PNG encoding failed: %s\n", spng_strerror(result));
    spng_ctx_free(ctx);
    fclose(fp);
    return -1;
  }

  // Finalize encoding by writing remaining chunks
  spng_encode_chunks(ctx);

  spng_ctx_free(ctx);
  fclose(fp);
  return 0;
#else
  fprintf(stderr, "SPNG support not enabled\n");
  abort();
#endif
}

ImageData read_jpg_file(const char *filename, void *allocator) {
#if defined(HAVE_JPEG)
  ImageData result = {0, 0, NULL};
  struct jpeg_error_mgr jerr;
  struct jpeg_decompress_struct cinfo;

  jpeg_create_decompress(&cinfo);
  cinfo.err = jpeg_std_error(&jerr);

  FILE *fp = fopen(filename, "rb");
  if (!fp)
    return result;

  size_t size;
  if (fseek(fp, 0, SEEK_END) < 0 || ((size = ftell(fp)) < 0) ||
      fseek(fp, 0, SEEK_SET) < 0) {
    fclose(fp);
    return result;
  }
  if (size == 0) {
    fclose(fp);
    return result;
  }

  jpeg_stdio_src(&cinfo, fp);
  jpeg_read_header(&cinfo, TRUE);
  jpeg_start_decompress(&cinfo);

  uint32_t width = cinfo.output_width;
  uint32_t height = cinfo.output_height;
  uint32_t channels = cinfo.output_components;

  JDIMENSION stride = width * channels;
  JSAMPARRAY temp_buffer =
      (*cinfo.mem->alloc_sarray)((j_common_ptr)&cinfo, JPOOL_IMAGE, stride, 1);

  result.width = width;
  result.height = height;
  result.data =
      (uint32_t *)zig_alloc(allocator, width * height * 4 * sizeof(uint8_t));
  if (!result.data) {
    jpeg_destroy_decompress(&cinfo);
    fclose(fp);
    return result;
  }

  uint8_t *image_buffer = (uint8_t *)result.data;

  while (cinfo.output_scanline < height) {
    jpeg_read_scanlines(&cinfo, temp_buffer, 1);

    unsigned int k = (cinfo.output_scanline - 1) * 4 * width;
    unsigned int j = 0;
    for (unsigned int i = 0; i < 4 * width; i += 4) {
      image_buffer[k + i] = temp_buffer[0][j];         // R
      image_buffer[k + i + 1] = temp_buffer[0][j + 1]; // G
      image_buffer[k + i + 2] = temp_buffer[0][j + 2]; // B
      image_buffer[k + i + 3] = 255;                   // A
      j += 3;
    }
  }

  jpeg_finish_decompress(&cinfo);
  jpeg_destroy_decompress(&cinfo);
  fclose(fp);

  return result;
#else
  fprintf(stderr, "JPEG support not enabled\n");
  abort();
#endif
}

ImageData read_tiff_file(const char *filename, void *allocator) {
#if defined(HAVE_TIFF)
  ImageData result = {0, 0, NULL};
  TIFF *image = TIFFOpen(filename, "r");
  if (!image)
    return result;

  int width, height;
  TIFFGetField(image, TIFFTAG_IMAGEWIDTH, &width);
  TIFFGetField(image, TIFFTAG_IMAGELENGTH, &height);

  result.width = width;
  result.height = height;
  result.data =
      (uint32_t *)zig_alloc(allocator, width * height * sizeof(uint32_t));
  if (!result.data) {
    TIFFClose(image);
    return result;
  }

  if (!TIFFReadRGBAImageOriented(image, width, height, result.data,
                                 ORIENTATION_TOPLEFT, 0)) {
    zig_free(allocator, result.data, width * height * sizeof(uint32_t));
    result.data = NULL;
    TIFFClose(image);
    return result;
  }

  TIFFClose(image);
  return result;
#else
  fprintf(stderr, "TIFF support not enabled\n");
  abort();
#endif
}

void free_image_data(ImageData *img, void *allocator) {
  if (img && allocator) {
    if (img->data) {
      size_t data_size = img->width * img->height * sizeof(uint32_t);
      zig_free(allocator, img->data, data_size);
    }
    zig_free(allocator, img, sizeof(ImageData));
  }
}

void free_image_data_ptr(uint32_t *data, void *allocator, size_t size) {
  if (data && allocator) {
    zig_free(allocator, data, size);
  }
}

ImageData read_webp_file(const char *filename, void *allocator) {
#if defined(HAVE_WEBP)
  ImageData result = {0, 0, NULL};

  FileBuffer file_buf = open_file_buffer(filename);
  if (!file_buf.data)
    return result;

  int width, height;

  // Get WebP image dimensions without decoding
  if (!WebPGetInfo((const uint8_t*)file_buf.data, file_buf.size, &width, &height)) {
    close_file_buffer(&file_buf);
    return result;
  }

  result.width = width;
  result.height = height;
  result.data = (uint32_t *)zig_alloc(allocator, width * height * sizeof(uint32_t));

  if (!result.data) {
    close_file_buffer(&file_buf);
    return result;
  }

  uint8_t* decoded_data = WebPDecodeRGBAInto((const uint8_t*)file_buf.data, file_buf.size,
                                             (uint8_t*)result.data, width * height * 4, width * 4);

  close_file_buffer(&file_buf);

  if (!decoded_data) {
    zig_free(allocator, result.data, width * height * sizeof(uint32_t));
    result.data = NULL;
    return result;
  }

  return result;
#else
  fprintf(stderr, "WebP support not enabled\n");
  abort();
#endif
}

