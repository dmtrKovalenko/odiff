#define CAML_NAME_SPACE

#include <spng.h>

#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/fail.h>
#include <caml/bigarray.h>

CAMLprim value
read_png_file(value file)
{
  CAMLparam1(file);
  CAMLlocal2(res, ba);

  int result = 0;
  FILE *png;
  spng_ctx *ctx = NULL;
  unsigned char *out = NULL;
  const char *filename = String_val(file);

  png = fopen(filename, "rb");
  if (png == NULL)
  {
    caml_failwith("error opening input file");
  }

  ctx = spng_ctx_new(0);

  if (ctx == NULL)
  {
    caml_failwith("spng_ctx_new() failed");
    spng_ctx_free(ctx);
    free(out);
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

  if (result)
  {
    caml_failwith("spng_get_ihdr() error!");
    spng_ctx_free(ctx);
    free(out);
  }

  size_t out_size;
  result = spng_decoded_image_size(ctx, SPNG_FMT_RGBA8, &out_size);
  if (result)
  {
    spng_ctx_free(ctx);
  };

  out = malloc(out_size);
  if (out == NULL)
  {
    spng_ctx_free(ctx);
    free(out);
  };

  result = spng_decode_image(ctx, out, out_size, SPNG_FMT_RGBA8, 0);
  if (result)
  {
    spng_ctx_free(ctx);
    free(out);
    caml_failwith(spng_strerror(result));
  }

  res = caml_alloc(4, 0);
  ba = caml_ba_alloc_dims(CAML_BA_INT32 | CAML_BA_C_LAYOUT, 1, out, out_size);

  Store_field(res, 0, Val_int(ihdr.width));
  Store_field(res, 1, Val_int(ihdr.height));
  Store_field(res, 2, ba);
  Store_field(res, 3, Val_bp(out));

  spng_ctx_free(ctx);

  CAMLreturn(res);
}
