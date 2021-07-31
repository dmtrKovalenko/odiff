#define CAML_NAME_SPACE

#include <stdio.h>

#include <jpeglib.h>

#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/fail.h>
#include <caml/bigarray.h>

CAMLprim value
read_jpeg_file_to_tuple(value file)
{
  CAMLparam1(file);
  CAMLlocal2(res, ba);

  size_t size;
  struct jpeg_error_mgr jerr;
  struct jpeg_decompress_struct cinfo;

  jpeg_create_decompress(&cinfo);
  cinfo.err = jpeg_std_error(&jerr);

  const char *filename = String_val(file);
  FILE *fp = fopen(filename, "rb");
  if (!fp) {
      caml_failwith("opening input file failed!");
  }
  if (fseek(fp, 0, SEEK_END) < 0 || ((size = ftell(fp)) < 0) || fseek(fp, 0, SEEK_SET) < 0) {
      caml_failwith("determining input file size failed");
  }
  if (size == 0) {
      caml_failwith("Input file contains no data");
  }

  jpeg_stdio_src(&cinfo, fp);
  jpeg_read_header(&cinfo, TRUE);
  jpeg_start_decompress(&cinfo);

  uint32_t width    = cinfo.output_width;
  uint32_t height   = cinfo.output_height;
  uint32_t channels = cinfo.output_components;

  JDIMENSION stride = width * channels;
  JSAMPARRAY temp_buffer = (*cinfo.mem->alloc_sarray)((j_common_ptr) &cinfo, JPOOL_IMAGE, stride, 1);

  int buffer_size = width * height;
  uint8_t *image_buffer = (uint8_t*)malloc(buffer_size * 4);

  while (cinfo.output_scanline < cinfo.output_height) {
    jpeg_read_scanlines(&cinfo, temp_buffer, 1);

    unsigned int k = (cinfo.output_scanline - 1) * 4 * width;
    unsigned int j = 0;
    for(unsigned int i = 0; i < 4 * width; i += 4) {
      image_buffer[k + i]     = temp_buffer[0][j];
      image_buffer[k + i + 1] = temp_buffer[0][j + 1];
      image_buffer[k + i + 2] = temp_buffer[0][j + 2];
      image_buffer[k + i + 3] = 255;

      j += 3;
    }
  }

  jpeg_finish_decompress(&cinfo);

  res = caml_alloc(4, 0);
  ba = caml_ba_alloc_dims(CAML_BA_INT32 | CAML_BA_C_LAYOUT, 1, image_buffer, buffer_size);

  Store_field(res, 0, Val_int(width));
  Store_field(res, 1, Val_int(height));
  Store_field(res, 2, ba);
  Store_field(res, 3, Val_bp(image_buffer));

  jpeg_destroy_decompress(&cinfo);
  fclose(fp);

  CAMLreturn(res);
}

CAMLprim value
cleanup_jpg(value buffer)
{
  CAMLparam1(buffer);
  free(Bp_val(buffer));
  CAMLreturn(Val_unit);
}
