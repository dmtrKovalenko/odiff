external load:
  string =>
  (
    int,
    int,
    Bigarray.Array1.t(int32, Bigarray.int32_elt, Bigarray.c_layout),
    'a,
  ) =
  "read_tiff_file_to_tuple";

[@noalloc] external cleanup_tiff: 'a => unit = "cleanup_tiff";
