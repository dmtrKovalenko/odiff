open Util;
open Odiff;

module IO: ImageIO.ImageIO = {
  type t = Rgba32.t;
  type row = int;
  let readRow = (_, y) => y;

  let loadImage = (filename): Odiff.ImageIO.img(t) => {
    let camlimage =
      switch (Images.load(filename, [])) {
      | Index8(i8img) => Index8.to_rgba32(i8img)
      | Rgb24(rgba24img) => Rgb24.to_rgba32(rgba24img)
      | Rgba32(img) => img
      | _ => raise(ImageIO.ImageNotLoaded)
      };

    {width: camlimage.width, height: camlimage.height, image: camlimage};
  };

  let saveImage = (img: ImageIO.img(t), filename) => {
    Png.save(filename, [], Images.Rgba32(img.image));
  };

  let readDirectPixel = (~x, ~y, img: ImageIO.img(Rgba32.t)) => {
    let (bytes, position) = Rgba32.unsafe_access(img.image, x, y);

    let r = Char.code(Bytes.unsafe_get(bytes, position + 0)) land 0xFF;
    let g = Char.code(Bytes.unsafe_get(bytes, position + 1)) land 0xFF;
    let b = Char.code(Bytes.unsafe_get(bytes, position + 2)) land 0xFF;
    let a = Char.code(Bytes.unsafe_get(bytes, position + 3)) land 0xFF;

    Int32.of_int(a lsl 24 + b lsl 16 + g lsl 8 + r);
  };

  let readImgColor = (x, y, img: ImageIO.img(t)) =>
    readDirectPixel(~x, ~y, img);

  let setImgColor = (x, y, (r, g, b), img: ImageIO.img(t)) => {
    let (bytes, position) = Rgba32.unsafe_access(img.image, x, y);

    Bytes.unsafe_set(bytes, position, r |> char_of_int);
    Bytes.unsafe_set(bytes, position + 1, g |> char_of_int);
    Bytes.unsafe_set(bytes, position + 2, b |> char_of_int);
    Bytes.unsafe_set(bytes, position + 3, 255 |> char_of_int);
  };

  let freeImage = _ => ();

  let makeSameAsLayout = (img: ImageIO.img(t)) => {
    {
      ...img,
      image:
        Rgba32.make(
          img.width,
          img.height,
          {
            color: {
              r: 0,
              g: 0,
              b: 0,
            },
            alpha: 0,
          },
        ),
    };
  };
};
