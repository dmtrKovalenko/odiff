module C = Configurator.V1;

C.main(~name="odiff-c-lib-package-resolver", _c => {
  let png_include_path = Sys.getenv("PNG_INCLUDE_PATH") |> String.trim;
  let png_lib_path = Sys.getenv("PNG_LIB_PATH") |> String.trim;
  let libpng16 = png_lib_path ++ "/libpng16.a";

  let spng_include_path = Sys.getenv("SPNG_INCLUDE_PATH") |> String.trim;
  let spng_lib_path = Sys.getenv("SPNG_LIB_PATH") |> String.trim;
  let libspng = spng_lib_path ++ "/libspng_static.a";

  let jpeg_include_path = Sys.getenv("JPEG_INCLUDE_PATH") |> String.trim;
  let jpeg_lib_path = Sys.getenv("JPEG_LIB_PATH") |> String.trim;
  let libjpeg = jpeg_lib_path ++ "/libjpeg.a";

  let tiff_include_path = Sys.getenv("TIFF_INCLUDE_PATH") |> String.trim;
  let tiff_lib_path = Sys.getenv("TIFF_LIB_PATH") |> String.trim;
  let libtiff = tiff_lib_path ++ "/libtiff.a";

  let z_lib_path = Sys.getenv("Z_LIB_PATH") |> String.trim;
  let zlib = z_lib_path ++ "/libz.a";

  C.Flags.write_sexp("png_write_c_flags.sexp", ["-I" ++ png_include_path]);
  C.Flags.write_sexp("png_write_c_library_flags.sexp", [libpng16, zlib]);
  C.Flags.write_sexp("png_write_flags.sexp", ["-cclib", libpng16]);

  C.Flags.write_sexp("png_c_flags.sexp", ["-I" ++ png_include_path]);
  C.Flags.write_sexp("png_c_library_flags.sexp", [libpng16, zlib]);
  C.Flags.write_sexp("png_flags.sexp", ["-cclib", libpng16]);

  C.Flags.write_sexp("png_ba_c_flags.sexp", ["-I" ++ spng_include_path]);
  C.Flags.write_sexp("png_ba_c_library_flags.sexp", [libspng, zlib]);
  C.Flags.write_sexp("png_ba_flags.sexp", ["-cclib", libspng]);

  C.Flags.write_sexp("jpg_c_flags.sexp", ["-I" ++ jpeg_include_path]);
  C.Flags.write_sexp("jpg_c_library_flags.sexp", [libjpeg]);
  C.Flags.write_sexp("jpg_flags.sexp", ["-cclib", libjpeg]);

  C.Flags.write_sexp("tiff_c_flags.sexp", ["-I" ++ tiff_include_path]);
  C.Flags.write_sexp("tiff_c_library_flags.sexp", [libtiff, zlib]);
  C.Flags.write_sexp("tiff_flags.sexp", ["-cclib", libtiff]);
});
