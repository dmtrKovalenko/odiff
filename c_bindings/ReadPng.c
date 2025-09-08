#define CAML_NAME_SPACE

#include <spng.h>

#include <caml/alloc.h>
#include <caml/bigarray.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>

CAMLprim value read_png_file(value file) {
  CAMLparam1(file);
  CAMLlocal2(res, ba);

  int result = 0;
  FILE *png;
  spng_ctx *ctx = NULL;
  const char *filename = String_val(file);

  png = fopen(filename, "rb");
  if (png == NULL) {
    caml_failwith("error opening input file");
  }

  ctx = spng_ctx_new(0);
  if (ctx == NULL) {
    fclose(png);
    caml_failwith("spng_ctx_new() failed");
  }

  /* Ignore and don't calculate chunk CRC's */
  spng_set_crc_action(ctx, SPNG_CRC_USE, SPNG_CRC_USE);

  /* Set memory usage limits for storing standard and unknown chunks,
      this is important when reading untrusted files! */
  size_t limit = 1024 * 1024 * 64;
  spng_set_chunk_limits(ctx, limit, limit);

  /* Set source PNG */
  spng_set_png_file(ctx, png);

  struct spng_ihdr ihdr;
  result = spng_get_ihdr(ctx, &ihdr);

  if (result) {
    spng_ctx_free(ctx);
    fclose(png);
    caml_failwith("spng_get_ihdr() error!");
  }

  size_t out_size;
  result = spng_decoded_image_size(ctx, SPNG_FMT_RGBA8, &out_size);
  if (result) {
    spng_ctx_free(ctx);
    fclose(png);
    caml_failwith(spng_strerror(result));
  };

  ba = caml_ba_alloc(CAML_BA_UINT8 | CAML_BA_C_LAYOUT | CAML_BA_MANAGED, 1,
                     NULL, &out_size);
  unsigned char *out = (unsigned char *)Caml_ba_data_val(ba);

  result =
      spng_decode_image(ctx, out, out_size, SPNG_FMT_RGBA8, SPNG_DECODE_TRNS);
  if (result) {
    spng_ctx_free(ctx);
    fclose(png);
    caml_failwith(spng_strerror(result));
  }

  spng_ctx_free(ctx);
  fclose(png);

  res = caml_alloc_tuple(3);
  Store_field(res, 0, Val_int(ihdr.width));
  Store_field(res, 1, Val_int(ihdr.height));
  Store_field(res, 2, ba);

  CAMLreturn(res);
}
