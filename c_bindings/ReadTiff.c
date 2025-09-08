#define CAML_NAME_SPACE
#include <caml/alloc.h>
#include <caml/bigarray.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>
#include <stdio.h>

#ifndef _WIN32
#include <tiffio.h>

CAMLprim value read_tiff_file_to_tuple(value file) {
  CAMLparam1(file);
  CAMLlocal2(res, ba);

  const char *filename = String_val(file);
  int width;
  int height;

  TIFF *image;

  if (!(image = TIFFOpen(filename, "r"))) {
    caml_failwith("opening input file failed!");
  }

  TIFFGetField(image, TIFFTAG_IMAGEWIDTH, &width);
  TIFFGetField(image, TIFFTAG_IMAGELENGTH, &height);

  int buffer_size = width * height;

  intnat dims[1] = {buffer_size};
  ba = caml_ba_alloc(CAML_BA_INT32 | CAML_BA_C_LAYOUT | CAML_BA_MANAGED, 1,
                     NULL, dims);

  uint32_t *buffer = (uint32_t *)Caml_ba_data_val(ba);

  if (!(TIFFReadRGBAImageOriented(image, width, height, buffer,
                                  ORIENTATION_TOPLEFT, 0))) {
    TIFFClose(image);
    caml_failwith("reading input file failed");
  }

  TIFFClose(image);

  res = caml_alloc_tuple(3);
  Store_field(res, 0, Val_int(width));
  Store_field(res, 1, Val_int(height));
  Store_field(res, 2, ba);

  CAMLreturn(res);
}
#else
CAMLprim value read_tiff_file_to_tuple(value file) {
  caml_failwith("Tiff files are not supported on Windows platform");
}
#endif
