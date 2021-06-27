#define CAML_NAME_SPACE

#include <stdio.h>

#include <turbojpeg.h>

#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/fail.h>
#include <caml/bigarray.h>

CAMLprim value
read_jpeg_file_to_tuple(value file)
{
  CAMLparam1(file);
  CAMLlocal1(res);

  size_t size;
  unsigned char *jpeg = NULL;
  tjhandle handle;

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

  jpeg = (unsigned char *)tjAlloc(size);
  if (!jpeg) {
      caml_failwith("allocating JPEG buffer failed");
  }

  if (fread(jpeg, size, 1, fp) < 1) {
      caml_failwith("reading input file failed");
  }

  if ((handle = tjInitDecompress()) == NULL) {
      caml_failwith("initializing decompressor failed");
  }

  int width, height;
  int inSubsamp, inColorspace;
  if (tjDecompressHeader3(handle, jpeg, size, &width, &height, &inSubsamp, &inColorspace) < 0) {
      caml_failwith("reading JPEG header failed");
  }

  int pixelFormat = TJPF_RGBA;
  tjscalingfactor scalingFactor = { 1, 1 };
  width = TJSCALED(width, scalingFactor);
  height = TJSCALED(height, scalingFactor);
  int pitch = width * tjPixelSize[pixelFormat];
  int flags = 0;
  int buffer_size = width * height * tjPixelSize[pixelFormat];
  unsigned char *buffer = NULL;

  if ((buffer = (unsigned char*)tjAlloc(buffer_size)) == NULL) {
      caml_failwith("allocating buffer failed");
  }

  if (tjDecompress2(handle, jpeg, size, buffer, width, pitch, height, pixelFormat, flags) < 0) {
      caml_failwith("decompressing JPEG image failed");
  }

  res = caml_alloc(3, 0);

  long dims[1] = {buffer_size};

  Store_field(res, 0, Val_int(width));
  Store_field(res, 1, Val_int(height));
  Store_field(res, 2, caml_ba_alloc(CAML_BA_INT32 | CAML_BA_C_LAYOUT, 1, buffer, dims));

  tjFree(jpeg);

  CAMLreturn(res);
}
