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

let flags_to_put = 
  match Sys.os_type with
  | "cUnix" -> conf.cflags
  | _ -> ["-LC:/vcpkg/packages/libpng_x86-windows/lib/pkgconfig/../../lib"; "-llibpng16"; "-lz"];

in
C.Flags.write_sexp "c_flags.sexp"         flags_to_put;
C.Flags.write_sexp "c_library_flags.sexp" conf.libs)