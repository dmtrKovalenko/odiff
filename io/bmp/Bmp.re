open Bigarray;

type data = Array1.t(int32, int32_elt, c_layout);

module IO: Odiff.ImageIO.ImageIO = {
  type t = data;

  let loadImage = (filename): Odiff.ImageIO.img(t) => {
    let (width, height, data) = ReadBmp.load(filename);

    {width, height, image: data};
  };

  [@inline]
  let readDirectPixel = (~x: int, ~y: int, img: Odiff.ImageIO.img(t)) => {
    let image: data = img.image;
    Array1.unsafe_get(image, y * img.width + x);
  };

  [@inline]
  let setImgColor = (~x, ~y, color, img: Odiff.ImageIO.img(t)) => {
    let image: data = img.image;
    Array1.unsafe_set(image, y * img.width + x, color);
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
