open Bigarray;
open Odiff.ImageIO;

type data = Array1.t(int32, int32_elt, c_layout);

module IO: Odiff.ImageIO.ImageIO = {
  type buffer;
  type t = {
    data,
    buffer,
  };

  let readDirectPixel = (~x: int, ~y: int, img) => {
    Array1.unsafe_get(img.image.data, y * img.width + x);
  };

  let setImgColor = (~x, ~y, color, img: Odiff.ImageIO.img(t)) => {
    Array1.unsafe_set(img.image.data, y * img.width + x, color);
  };

  let loadImage = (filename): Odiff.ImageIO.img(t) => {
    let (width, height, data, buffer) = ReadPng.read_png_image(filename);

    {
      width,
      height,
      image: {
        data,
        buffer,
      },
    };
  };

  let saveImage = (img: Odiff.ImageIO.img(t), filename) => {
    ();
      // WritePng.write_png_bigarray(filename, img.image, img.width, img.height);
  };

  let freeImage = (img: Odiff.ImageIO.img(t)) => {
    ();
  };

  let makeSameAsLayout = (img: Odiff.ImageIO.img(t)) => {
    let data = Array1.create(int32, c_layout, Array1.dim(img.image.data));
    {
      ...img,
      image: {
        data,
        buffer: img.image.buffer,
      },
    };
  };
};
