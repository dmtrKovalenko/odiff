import { compare } from "../npm_package/odiff";

// allow no options
compare("path1", "path2", "path3")

// @ts-expect-error options can be only object
compare("path1", "path2", "path3", "")

// allow partial options
compare("path1", "path2", "path3", {
  antialiasing: true,
  threshold: 2,
});

compare("path1", "path2", "path3", {
  antialiasing: true,
  threshold: 2,
  // @ts-expect-error invalid field
  ab: true
});