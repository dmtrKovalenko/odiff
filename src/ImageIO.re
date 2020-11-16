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

let saveImage = (filename, imageBuffer) =>
  Images.Rgba32(imageBuffer) |> Png.save(filename, []);

let readImgColor = (x, y, img) => {
  let (bytes, position) = Rgba32.unsafe_access(img, x, y);

  (
    Bytes.unsafe_get(bytes, position) |> Char.code,
    Bytes.unsafe_get(bytes, position + 1) |> Char.code,
    Bytes.unsafe_get(bytes, position + 2) |> Char.code,
    Bytes.unsafe_get(bytes, position + 3) |> Char.code,
  );
};

let readImgAlpha = (x, y, img) => {
  let (bytes, position) = Rgba32.unsafe_access(img, x, y);

  Bytes.unsafe_get(bytes, position + 3) |> Char.code;
};

let setImgColor = (x, y, (r, g, b, a), img) => {
  let (bytes, position) = Rgba32.unsafe_access(img, x, y);

  Bytes.unsafe_set(bytes, position, r);
  Bytes.unsafe_set(bytes, position + 1, g);
  Bytes.unsafe_set(bytes, position + 2, b);
  Bytes.unsafe_set(bytes, position + 3, a);
};