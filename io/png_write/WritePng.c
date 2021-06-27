#define CAML_NAME_SPACE
#include <stdio.h>
#include <string.h>
#include <png.h>
#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/fail.h>
#include <caml/bigarray.h>

CAMLprim value write_png_file(png_bytep *row_pointers, value width_value, value height_value, value filename_value)
{
  CAMLparam3(height_value, width_value, filename_value);
  int height = Int_val(height_value);
  int width = Int_val(width_value);

  FILE *fp = fopen(String_val(filename_value), "wb");
  if (!fp)
    caml_failwith("Can not save the output :(");

  png_structp png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
  if (!png)
    caml_failwith("Can not save the output :(");

  png_infop info = png_create_info_struct(png);
  if (!info)
    caml_failwith("Can not save the output :(");

  if (setjmp(png_jmpbuf(png)))
    caml_failwith("Can not save the output :(");

  png_init_io(png, fp);

  // Output is 8bit depth, RGBA format.
  png_set_IHDR(
      png,
      info,
      width, height,
      8,
      PNG_COLOR_TYPE_RGBA,
      PNG_INTERLACE_NONE,
      PNG_COMPRESSION_TYPE_DEFAULT,
      PNG_FILTER_TYPE_DEFAULT);

  png_write_info(png, info);

  if (!row_pointers)
    caml_failwith("Can not save the output :(");

  png_set_compression_level(png, 2);
  png_set_filter(png, 0, PNG_FILTER_NONE);
  png_write_image(png, row_pointers);
  png_write_end(png, NULL);

  fclose(fp);

  png_destroy_write_struct(&png, &info);

  CAMLreturn(Val_unit);
}

void write_png(const char *name, const char *data, int w, int h)
{
  FILE *fp;
  png_structp png_ptr;
  png_infop info_ptr;

  if (( fp = fopen(name, "wb")) == NULL ){
    caml_failwith("Can not save the output :(");
  }

  if ((png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL)) == NULL){
    fclose(fp);
    caml_failwith("Can not save the output :(");
  }

  if( (info_ptr = png_create_info_struct(png_ptr)) == NULL ){
    fclose(fp);
    png_destroy_write_struct(&png_ptr, (png_infopp)NULL);
    caml_failwith("Can not save the output :(");
  }

  /* error handling */
  if (setjmp(png_jmpbuf(png_ptr))) {
    /* Free all of the memory associated with the png_ptr and info_ptr */
    png_destroy_write_struct(&png_ptr, &info_ptr);
    fclose(fp);
    /* If we get here, we had a problem writing the file */
    caml_failwith("Can not save the output :(");
  }

  png_init_io(png_ptr, fp);

  png_set_IHDR(
    png_ptr, info_ptr, w, h,
    8,
    PNG_COLOR_TYPE_RGB_ALPHA,
    PNG_INTERLACE_ADAM7,
    PNG_COMPRESSION_TYPE_DEFAULT,
    PNG_FILTER_TYPE_DEFAULT
  );

  png_write_info(png_ptr, info_ptr);

  png_bytep *row_pointers;

  row_pointers = (png_bytep *)malloc(sizeof(png_bytep) * h);
  int rowbytes = png_get_rowbytes(png_ptr, info_ptr);

  for (int y = 0; y < h; y++)
  {
    row_pointers[y] = (png_bytep)(data + rowbytes * y);
  }

  png_write_image(png_ptr, row_pointers);
  free((void*)row_pointers);

  png_write_end(png_ptr, info_ptr);
  png_destroy_write_struct(&png_ptr, &info_ptr);

  fclose(fp);
}

value write_png_bigarray(value name, value bigarray, value width, value height)
{
  CAMLparam4(name, bigarray, width, height);

  int w = Int_val(width);
  int h = Int_val(height);
  const char *buf = Caml_ba_data_val(bigarray);
  const char *filename = String_val(name);

  write_png(filename, buf, w, h);

  CAMLreturn(Val_unit);
}

value write_png_buffer(value name, value buffer, value width, value height)
{
  CAMLparam4(name, buffer, width, height);

  int w = Int_val(width);
  int h = Int_val(height);
  const char *buf = String_val(buffer);
  const char *filename = String_val(name);

  write_png(filename, buf, w, h);

  CAMLreturn(Val_unit);
}
