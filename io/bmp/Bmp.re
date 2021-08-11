open Bigarray;

type data = Array1.t(int32, int32_elt, c_layout);

module IO = {
  type t = data;
  type row = int;

  let loadImage = (filename): Odiff.ImageIO.img(t) => {
    let (width, height, image) = ReadBmp.load(filename);

    {width, height, image};
  };

  let readDirectPixel = (~x, ~y, img: Odiff.ImageIO.img(t)) => {
    (img.image).{y * img.width + x};
  };

  let setImgColor = (~x, ~y, color, img: Odiff.ImageIO.img(t)) => {
    Array1.unsafe_set(img.image, y * img.width + x, color);
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
