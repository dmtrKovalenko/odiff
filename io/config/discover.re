module C = Configurator.V1;

C.main(~name="odiff-c-lib-package-resolver", _c => {
  let png_include_path = Sys.getenv("PNG_INCLUDE_PATH") |> String.trim;
  let png_lib_path = Sys.getenv("PNG_LIB_PATH") |> String.trim;

  let z_lib_path = Sys.getenv("Z_LIB_PATH") |> String.trim;

  C.Flags.write_sexp("c_flags.sexp", ["-I" ++ png_include_path]);

  C.Flags.write_sexp(
    "c_library_flags.sexp",
    [png_lib_path ++ "/libpng16.a", z_lib_path ++ "/libz.a"],
  );

  C.Flags.write_sexp(
    "flags.sexp",
    ["-cclib", png_lib_path ++ "/libpng16.a"],
  );
});
