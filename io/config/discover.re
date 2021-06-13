module C = Configurator.V1;

C.main(~name="odiff-c-lib-package-resolver", c => {
  let resolved_cflags_for_windows = Sys.getenv("CFLAGS") |> String.trim;
  let resolved_libsflags_for_windows = Sys.getenv("LDFLAGS") |> String.trim;
  let png_lib_path = Sys.getenv("PNG_LIB_PATH") |> String.trim;

  let default: C.Pkg_config.package_conf = {libs: ["libpng"], cflags: []};

  let conf =
    switch (C.Pkg_config.get(c)) {
    | None => default
    | Some(pc) =>
      switch (C.Pkg_config.query(pc, ~package="libpng")) {
      | None => default
      | Some(deps) => deps
      }
    };

  if (resolved_cflags_for_windows !== String.concat("", conf.cflags)) {
    Printf.printf(
      "\nAuto resolved c flags from env are different from pkg-config results, \n PKG-CONFIG: %s \n CLFAGS: %s",
      String.concat(" ", conf.cflags),
      resolved_cflags_for_windows,
    );
  };

  if (resolved_libsflags_for_windows !== String.concat("", conf.libs)) {
    Printf.printf(
      "\nAuto resolved libs flags from env are different from pkg-config results, \n PKG-CONFIG: %s \n LDFLAGS: %s",
      String.concat(" ", conf.libs),
      resolved_libsflags_for_windows,
    );
  };

  C.Flags.write_sexp(
    "c_flags.sexp",
    String.split_on_char(' ', resolved_cflags_for_windows),
  );

  C.Flags.write_sexp(
    "c_library_flags.sexp",
    String.split_on_char(' ', resolved_libsflags_for_windows),
  );

  C.Flags.write_sexp("flags.sexp", ["-cclib", png_lib_path ++ "/libpng.a"]);
});
