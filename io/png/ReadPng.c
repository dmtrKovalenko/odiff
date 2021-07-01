#define CAML_NAME_SPACE
#include <stdio.h>
#include <string.h>
#include <png.h>
#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/fail.h>
#include <caml/bigarray.h>

char *concat(const char *s1, const char *s2)
{
  const size_t len1 = strlen(s1);
  const size_t len2 = strlen(s2);
  char *result = malloc(len1 + len2 + 1); // +1 for the null-terminator

  memcpy(result, s1, len1);
  memcpy(result + len1, s2, len2 + 1); // +1 to copy the null-terminator
  return result;
}

CAMLprim value
read_png_file_to_tuple(value file)
{
  CAMLparam1(file);
  CAMLlocal2(res, ba);

  int width, height;
  png_byte color_type;
  png_byte bit_depth;
  png_bytep *row_pointers = NULL;

  const char *filename = String_val(file);
  FILE *fp = fopen(filename, "rb");

  png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
  if (!png)
    caml_failwith(concat("Can not read the file -", filename));

  png_infop info = png_create_info_struct(png);
  if (!info)
    caml_failwith(concat("Incorrect file type -", filename));

  if (setjmp(png_jmpbuf(png)))
    caml_failwith(concat("Can not read the file -", filename));

  png_init_io(png, fp);

  png_read_info(png, info);

  width = png_get_image_width(png, info);
  height = png_get_image_height(png, info);
  color_type = png_get_color_type(png, info);
  bit_depth = png_get_bit_depth(png, info);

  // Read any color_type into 8bit depth, RGBA format.
  // See http://www.libpng.org/pub/png/libpng-manual.txt

  if (bit_depth == 16)
    png_set_strip_16(png);

  if (color_type == PNG_COLOR_TYPE_PALETTE)
    png_set_palette_to_rgb(png);

  // PNG_COLOR_TYPE_GRAY_ALPHA is always 8 or 16bit depth.
  if (color_type == PNG_COLOR_TYPE_GRAY && bit_depth < 8)
    png_set_expand_gray_1_2_4_to_8(png);

  if (png_get_valid(png, info, PNG_INFO_tRNS))
    png_set_tRNS_to_alpha(png);

  // These color_type don't have an alpha channel then fill it with 0xff.
  if (color_type == PNG_COLOR_TYPE_RGB ||
      color_type == PNG_COLOR_TYPE_GRAY ||
      color_type == PNG_COLOR_TYPE_PALETTE)
    png_set_filler(png, 0xFF, PNG_FILLER_AFTER);

  if (color_type == PNG_COLOR_TYPE_GRAY ||
      color_type == PNG_COLOR_TYPE_GRAY_ALPHA)
    png_set_gray_to_rgb(png);

  png_read_update_info(png, info);

  row_pointers = (png_bytep *)malloc(sizeof(png_bytep) * height);
  int rowbytes = png_get_rowbytes(png, info);

  for (int y = 0; y < height; y++)
  {
    row_pointers[y] = (png_byte *)malloc(rowbytes);
  }

  png_read_image(png, row_pointers);

  fclose(fp);

  png_destroy_read_struct(&png, &info, NULL);

  res = caml_alloc(4, 0);

  Store_field(res, 0, Val_int(width));
  Store_field(res, 1, Val_int(height));
  Store_field(res, 2, Val_int(rowbytes));
  Store_field(res, 3, Val_bp(row_pointers));

  CAMLreturn(res);
}

CAMLprim value
row_pointers_to_bigarray(png_bytep *row_pointers, value rowbytes_val, value height_val, value width_val)
{
  CAMLparam3(rowbytes_val, height_val, width_val);

  int width = Int_val(width_val);
  int height = Int_val(height_val);
  int rowbytes = Int_val(rowbytes_val);

  unsigned char *total_pixels = malloc(height * rowbytes);

  for (int y = 0; y < height; y++)
  {
    memcpy(total_pixels + y * rowbytes, row_pointers[y], rowbytes);
  }

  long dims[1] = {width * height};
  CAMLreturn(caml_ba_alloc(CAML_BA_INT32 | CAML_BA_C_LAYOUT, 1, total_pixels, dims));
}

CAMLprim value
create_empty_img(value height_val, value width_val)
{
  CAMLparam2(height_val, width_val);
  int width = Int_val(width_val);
  int height = Int_val(height_val);

  png_bytep *row_pointers = (png_bytep *)malloc(sizeof(png_bytep) * height);

  for (int y = 0; y < height; y++)
  {
    row_pointers[y] = (png_byte *)malloc(width * 4); // we always use RGBA
  }

  CAMLreturn(Val_bp(row_pointers));
}

CAMLprim value
read_row(png_bytep *row_pointers, value y_val, value img_width_val)
{
  CAMLparam2(y_val, img_width_val);
  int y = Int_val(y_val);
  int img_width = Int_val(img_width_val);

  png_bytep row = row_pointers[y];

  long dims[] = {img_width};
  CAMLreturn(caml_ba_alloc(CAML_BA_INT32 | CAML_BA_C_LAYOUT, 1, row, dims));
}

CAMLprim value
set_pixel_data(png_bytep *row_pointers, value x_val, value y_val, value pixel_val)
{
  CAMLparam3(x_val, y_val, pixel_val);

  int x = Int_val(x_val);
  int y = Int_val(y_val);

  png_bytep row = row_pointers[y];
  png_bytep px = &(row[x * 4]);

  px[0] = Int_val(Field(pixel_val, 0));
  px[1] = Int_val(Field(pixel_val, 1));
  px[2] = Int_val(Field(pixel_val, 2));
  px[3] = 255;

  CAMLreturn(Val_unit);
}

CAMLprim value
free_row_pointers(png_bytep *row_pointers, value height_value)
{
  CAMLparam1(height_value);
  int height = Int_val(height_value);

  for (int y = 0; y < height; y++)
  {
    free(row_pointers[y]);
  }

  free(row_pointers);

  CAMLreturn(Val_unit);
}
