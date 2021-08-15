open Bigarray;
open Odiff.ImageIO;

type data = Array1.t(int32, int32_elt, c_layout);

module IO: Odiff.ImageIO.ImageIO = {
  type t = data;

  let readDirectPixel = (~x: int, ~y: int, img: Odiff.ImageIO.img(t)) => {
    let image: data = img.image;
    Array1.unsafe_get(image, y * img.width + x);
  };

  let setImgColor = (~x, ~y, color, img: Odiff.ImageIO.img(t)) => {
    let image: data = img.image;
    Array1.unsafe_set(image, y * img.width + x, color);
  };

  let loadImage = (filename): Odiff.ImageIO.img(t) => {
    let (width, height, data, _buffer) = ReadPng.read_png_image(filename);

    {width, height, image: data};
  };

  let saveImage = (img: Odiff.ImageIO.img(t), filename) => {
    WritePng.write_png_bigarray(filename, img.image, img.width, img.height);
  };

  let freeImage = (img: Odiff.ImageIO.img(t)) => {
    ();
  };

  let makeSameAsLayout = (img: Odiff.ImageIO.img(t)) => {
    let image = Array1.create(int32, c_layout, Array1.dim(img.image));
    {...img, image};
  };
};
