#define CAML_NAME_SPACE

#include <stdio.h>

#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/fail.h>
#include <caml/bigarray.h>

#include <tiffio.h>

CAMLprim value
read_tiff_file_to_tuple(value file)
{
  CAMLparam1(file);
  CAMLlocal1(res);

  const char *filename = String_val(file);
  uint32_t *buffer = NULL;
  int width;
  int height;

  TIFF *image;



  if (!(image = TIFFOpen(filename, "r"))) {
    caml_failwith("opening input file failed!");
  }

  TIFFGetField(image, TIFFTAG_IMAGEWIDTH, &width);
  TIFFGetField(image, TIFFTAG_IMAGELENGTH, &height);


  int buffer_size = width * height;
  buffer = (uint32_t*)malloc(buffer_size * 4);

  if (!buffer) {
    TIFFClose(image);
    caml_failwith("allocating TIFF buffer failed");
  }


  if (!(TIFFReadRGBAImageOriented(image, width, height, buffer, ORIENTATION_TOPLEFT, 0))) {
    TIFFClose(image);
    caml_failwith("reading input file failed");
  }

  res = caml_alloc(3, 0);

  long dims[1] = {buffer_size};

  Store_field(res, 0, Val_int(width));
  Store_field(res, 1, Val_int(height));
  Store_field(res, 2, caml_ba_alloc(CAML_BA_INT32 | CAML_BA_C_LAYOUT, 1, buffer, dims));

  TIFFClose(image);

  CAMLreturn(res);
}
