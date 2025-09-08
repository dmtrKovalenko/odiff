#define CAML_NAME_SPACE

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <caml/bigarray.h>
#include <caml/fail.h>
#include <caml/memory.h>

#include <spng.h>

char *concat(const char *s1, const char *s2) {
  char *result =
      malloc(strlen(s1) + strlen(s2) + 1); // +1 for the null-terminator

  if (result == NULL) {
    caml_failwith("Can not concat strings");
  }

  strcpy(result, s1);
  strcat(result, s2);

  return result;
}

value write_png_bigarray(value filename_val, value bigarray, value width_val,
                         value height_val) {
  CAMLparam4(filename_val, bigarray, width_val, height_val);

  int width = Int_val(width_val);
  int height = Int_val(height_val);
  const char *data = Caml_ba_data_val(bigarray);
  const char *filename = String_val(filename_val);

  FILE *fp;
  if ((fp = fopen(filename, "wb")) == NULL) {
    char *err = strerror(errno);
    char *message = concat("Can not write diff output. fopen error: ", err);

    caml_failwith(message);

    free(err);
    free(message);
  }

  int result = 0;

  uint8_t bit_depth = 8;
  uint8_t color_type = SPNG_COLOR_TYPE_TRUECOLOR_ALPHA;
  uint8_t compression_method = 0;
  uint8_t filter_method = SPNG_FILTER_NONE;
  uint8_t interlace_method = SPNG_INTERLACE_NONE;

  size_t out_size = width * height * 4;
  size_t out_width = out_size / height;

  spng_ctx *ctx = spng_ctx_new(SPNG_CTX_ENCODER);
  struct spng_ihdr ihdr = {
      width,
      height,
      bit_depth,
      color_type,
      compression_method,
      filter_method,
      interlace_method,
  };

  result = spng_set_ihdr(ctx, &ihdr);
  if (result) {
    spng_ctx_free(ctx);
    fclose(fp);
    caml_failwith(spng_strerror(result));
  }

  result = spng_set_option(ctx, SPNG_FILTER_CHOICE, SPNG_DISABLE_FILTERING);
  if (result) {
    spng_ctx_free(ctx);
    fclose(fp);
    caml_failwith(spng_strerror(result));
  }

  result = spng_set_png_file(ctx, fp);
  if (result) {
    fclose(fp);
    spng_ctx_free(ctx);
    caml_failwith(spng_strerror(result));
  }

  result = spng_encode_image(ctx, 0, 0, SPNG_FMT_PNG, SPNG_ENCODE_PROGRESSIVE);

  if (result) {
    fclose(fp);
    spng_ctx_free(ctx);
    caml_failwith(spng_strerror(result));
  }

  for (int i = 0; i < ihdr.height; i++) {
    const char *row = data + out_width * i;
    result = spng_encode_scanline(ctx, row, out_width);
    if (result)
      break;
  }

  if (result != SPNG_EOI) {
    spng_ctx_free(ctx);
    fclose(fp);
    caml_failwith(spng_strerror(result));
  }

  spng_encode_chunks(ctx);
  spng_ctx_free(ctx);
  fclose(fp);

  CAMLreturn(Val_unit);
}
