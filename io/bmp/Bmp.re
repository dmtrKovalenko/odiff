open Bigarray;

type data = Array1.t(int32, int32_elt, c_layout);

module IO: Odiff.ImageIO.ImageIO = {
  /* This needs to be put inside a record, because for some reason, reads are faster that way. */
  type t = {data};

  let loadImage = (filename): Odiff.ImageIO.img(t) => {
    let (width, height, data) = ReadBmp.load(filename);

    {
      width,
      height,
      image: {
        data: data,
      },
    };
  };

  let readDirectPixel = (~x: int, ~y: int, img: Odiff.ImageIO.img(t)) => {
    Array1.unsafe_get(img.image.data, y * img.width + x);
  };

  let setImgColor = (~x, ~y, color, img: Odiff.ImageIO.img(t)) => {
    Array1.unsafe_set(img.image.data, y * img.width + x, color);
  };

  let saveImage = (img: Odiff.ImageIO.img(t), filename) => {
    WritePng.write_png_bigarray(
      filename,
      img.image.data,
      img.width,
      img.height,
    );
  };

  let freeImage = (img: Odiff.ImageIO.img(t)) => {
    ();
  };

  let makeSameAsLayout = (img: Odiff.ImageIO.img(t)) => {
    let data = Array1.create(int32, c_layout, Array1.dim(img.image.data));
    {
      ...img,
      image: {
        data: data,
      },
    };
  };
};
