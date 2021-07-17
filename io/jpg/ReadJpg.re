external read_jpeg_image:
  string =>
  (
    int,
    int,
    Bigarray.Array1.t(int32, Bigarray.int32_elt, Bigarray.c_layout),
    'a,
  ) =
  "read_jpeg_file_to_tuple";

[@noalloc] external cleanup_jpg: 'a => unit = "cleanup_jpg";
