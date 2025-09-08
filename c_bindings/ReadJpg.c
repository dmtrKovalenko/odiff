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
      fclose(fp);
      caml_failwith("determining input file size failed");
  }
  if (size == 0) {
      fclose(fp);
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

  int buffer_size = width * height * 4;
  intnat dims[1] = {buffer_size};
  ba = caml_ba_alloc(CAML_BA_UINT8 | CAML_BA_C_LAYOUT | CAML_BA_MANAGED, 1, NULL, dims);
  uint8_t *image_buffer = (uint8_t *)Caml_ba_data_val(ba);

  while (cinfo.output_scanline < height) {
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
  jpeg_destroy_decompress(&cinfo);
  fclose(fp);

  res = caml_alloc_tuple(3);
  Store_field(res, 0, Val_int(width));
  Store_field(res, 1, Val_int(height));
  Store_field(res, 2, ba);

  CAMLreturn(res);
}
