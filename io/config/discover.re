module C = Configurator.V1;

C.main(~name="odiff-c-lib-package-resolver", _c => {
  let png_include_path = Sys.getenv("PNG_INCLUDE_PATH") |> String.trim;
  let png_lib_path = Sys.getenv("PNG_LIB_PATH") |> String.trim;
  let libpng16 = png_lib_path ++ "/libpng16.a";

  let z_lib_path = Sys.getenv("Z_LIB_PATH") |> String.trim;
  let zlib = z_lib_path ++ "/libz.a";

  C.Flags.write_sexp("png_write_c_flags.sexp", ["-I" ++ png_include_path]);
  C.Flags.write_sexp("png_write_c_library_flags.sexp", [libpng16, zlib]);
  C.Flags.write_sexp("png_write_flags.sexp", ["-cclib", libpng16]);

  C.Flags.write_sexp("png_c_flags.sexp", ["-I" ++ png_include_path]);
  C.Flags.write_sexp("png_c_library_flags.sexp", [libpng16, zlib]);
  C.Flags.write_sexp("png_flags.sexp", ["-cclib", libpng16]);

});
