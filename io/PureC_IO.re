open Odiff.ImageIO;

module IO: Odiff.ImageIO.ImageIO = {
  type rowPointers;
  type t = {
    rowPointers,
    bigarray:
      Bigarray.Array1.t(int, Bigarray.int8_unsigned_elt, Bigarray.c_layout),
  };

  type row = int;
  // Bigarray.Array1.t(int, Bigarray.int8_unsigned_elt, Bigarray.c_layout);

  let readRow = (img: Odiff.ImageIO.img(t), y): row => {
    // ReadPng.read_row(img.image, y, img.width);
    y;
  };

  let readImgColor = (x, row: row, img: Odiff.ImageIO.img(t)) => {
    (
      (img.image.bigarray).{row * img.width * 4 + x * 4 + 0},
      (img.image.bigarray).{row * img.width * 4 + x * 4 + 1},
      (img.image.bigarray).{row * img.width * 4 + x * 4 + 2},
      (img.image.bigarray).{row * img.width * 4 + x * 4 + 3},
      // (row.{x * 4}, row.{x * 4 + 1}, row.{x * 4 + 2}, row.{x * 4 + 3});
    );
  };

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
    ReadPng.write_png_file(img.image.rowPointers, img.width, img.height, filename);
  };

  let freeImage = (img: Odiff.ImageIO.img(t)) => {
    ReadPng.free_row_pointers(img.image, img.height);
  };

  let makeSameAsLayout = (img: Odiff.ImageIO.img(t)) => {
    {...img, image: ReadPng.create_empty_img(img.height, img.width)};
  };
};
