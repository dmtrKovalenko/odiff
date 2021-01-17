module C = Configurator.V1

let () =
C.main ~name:"odiff-c-lib-package-resolver" (fun c ->
let default : C.Pkg_config.package_conf =
  { libs   = ["libpng"]
  ; cflags = []
  }
in
let conf =
  match C.Pkg_config.get c with
  | None -> default
  | Some pc ->
     match (C.Pkg_config.query pc ~package:"libpng") with
     | None -> default
     | Some deps -> deps
in

Printf.printf "Resolved c flags %s" (String.concat "" conf.cflags);
Printf.printf "\nResolved c libs %s" (String.concat "" conf.libs);


C.Flags.write_sexp "c_flags.sexp"         conf.cflags;
C.Flags.write_sexp "c_library_flags.sexp" conf.libs)