open Util;

exception ImageNotLoaded;

let loadImage = filename => {
  switch (Images.load(filename, [])) {
  | Index8(i8img) => Index8.to_rgba32(i8img)
  | Rgb24(rgba24img) => Rgb24.to_rgba32(rgba24img)
  | Rgba32(img) => img
  | imgTyp => raise(ImageNotLoaded)
  };
};

let readImgColor = (x, y, img) => {
  let (bytes, position) = Rgba32.unsafe_access(img, x, y);

  (
    bytes @% position,
    bytes @% position + 1,
    bytes @% position + 2,
    bytes @% position + 3,
  );
};

let setImgColor = (x, y, (r, g, b, a), img) => {
  let (bytes, position) = Rgba32.unsafe_access(img, x, y);

  bytes << position & char_of_int(r);
  bytes << position + 1 & char_of_int(g);
  bytes << position + 2 & char_of_int(b);
  bytes << position + 3 & char_of_int(a);
};