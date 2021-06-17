open Odiff.ImageIO;

module IO: Odiff.ImageIO.ImageIO = {
  type rowPointers = int;
  type t = {
    rowPointers,
    bigarray: Bigarray.Array1.t(int32, Bigarray.int32_elt, Bigarray.c_layout),
  };

  type row = int;
  let readDirectPixel = (~x: int, ~y: int, img) => {
    (img.image.bigarray).{y * img.width + x};
  };

  let readRow = (img: Odiff.ImageIO.img(t), y): row => y;
  // row is always an int, so we can read pixel directly
  let readImgColor = (x, row: row, img: Odiff.ImageIO.img(t)) =>
    readDirectPixel(~x, ~y=row, img);

  let setImgColor = (x, y, pixel, img: Odiff.ImageIO.img(t)) => {
    ReadPng.set_pixel_data(img.image.rowPointers, x, y, pixel);
  };

  let loadImage = (filename): Odiff.ImageIO.img(t) => {
    let (width, height, rowbytes, rowPointers) =
      ReadPng.read_png_image(filename);

    let bigarray =
      ReadPng.row_pointers_to_bigarray(rowPointers, rowbytes, height, width);

    {
      width,
      height,
      image: {
        bigarray,
        rowPointers,
      },
    };
  };

  let saveImage = (img: Odiff.ImageIO.img(t), filename) => {
    ReadPng.write_png_file(
      img.image.rowPointers,
      img.width,
      img.height,
      filename,
    );
  };

  let freeImage = (img: Odiff.ImageIO.img(t)) => {
    ReadPng.free_row_pointers(img.image.rowPointers, img.height);
  };

  let makeSameAsLayout = (img: Odiff.ImageIO.img(t)) => {
    {
      ...img,
      image: {
        rowPointers: ReadPng.create_empty_img(img.height, img.width),
        bigarray: img.image.bigarray,
      },
    };
  };
};
