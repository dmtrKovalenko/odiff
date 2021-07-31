open Bigarray;

type bicompression =
  | BI_RGB
  | BI_RLE8
  | BI_RLE4
  | BI_BITFIELDS;

type bibitcount =
  | Monochrome
  | Color16
  | Color256
  | ColorRGB
  | ColorRGBA;

type bitmapfileheader = {
  bfType: int,
  bfSize: int,
  bfReserved1: int,
  bfReserved2: int,
  bfOffBits: int,
};

type bitmapinfoheader = {
  biSize: int,
  biWidth: int,
  biHeight: int,
  biPlanes: int,
  biBitCount: bibitcount,
  biCompression: bicompression,
  biSizeImage: int,
  biXPelsPerMeter: int,
  biYPelsPerMeter: int,
  biClrUsed: int,
  biClrImportant: int,
};

type bmp = {
  bmpFileHeader: bitmapfileheader,
  bmpInfoHeader: bitmapinfoheader,
  bmpBytes: Bigarray.Array1.t(int32, Bigarray.int32_elt, Bigarray.c_layout),
};

let bytes_read = ref(0);

let read_byte = ic => {
  incr(bytes_read);
  input_byte(ic);
};
let skip_byte = ic => {
  incr(bytes_read);
  ignore(input_byte(ic));
};

let read_16bit = ic => {
  let b0 = read_byte(ic);
  let b1 = read_byte(ic);

  b1 lsl 8 + b0;
};

let read_32bit = ic => {
  let b0 = read_byte(ic);
  let b1 = read_byte(ic);
  let b2 = read_byte(ic);
  let b3 = read_byte(ic);

  b3 lsl 24 + b2 lsl 16 + b1 lsl 8 + b0;
};

let read_bit_count = ic =>
  switch (read_16bit(ic)) {
  | 1 => Monochrome
  | 4 => Color16
  | 8 => Color256
  | 24 => ColorRGB
  | 32 => ColorRGBA
  | n => failwith("invalid number of colors in bitmap: " ++ string_of_int(n))
  };

let read_compression = ic =>
  switch (read_32bit(ic)) {
  | 0 => BI_RGB
  | 1 => BI_RLE8
  | 2 => BI_RLE4
  | 3 => BI_BITFIELDS
  | n => failwith("invalid compression: " ++ string_of_int(n))
  };

let load_bitmapfileheader = ic => {
  let bfType = read_16bit(ic);
  if (bfType != 19778) {
    failwith("Invalid bitmap file");
  };
  let bfSize = read_32bit(ic);
  let bfReserved1 = read_16bit(ic);
  let bfReserved2 = read_16bit(ic);
  let bfOffBits = read_32bit(ic);
  {bfType, bfSize, bfReserved1, bfReserved2, bfOffBits};
};

let load_bitmapinfoheader = ic =>
  try({
    let biSize = read_32bit(ic);
    let biWidth = read_32bit(ic);
    let biHeight = read_32bit(ic);
    let biPlanes = read_16bit(ic);
    let biBitCount = read_bit_count(ic);
    let biCompression = read_compression(ic);
    let biSizeImage = read_32bit(ic);
    let biXPelsPerMeter = read_32bit(ic);
    let biYPelsPerMeter = read_32bit(ic);
    let biClrUsed = read_32bit(ic);
    let biClrImportant = read_32bit(ic);
    {
      biSize,
      biWidth,
      biHeight,
      biPlanes,
      biBitCount,
      biCompression,
      biSizeImage,
      biXPelsPerMeter,
      biYPelsPerMeter,
      biClrUsed,
      biClrImportant,
    };
  }) {
  | Failure(s) as e =>
    prerr_endline(s);
    raise(e);
  };

let load_image24data = (bih, ic) => {
  let data = Array1.create(int32, c_layout, bih.biWidth * bih.biHeight);
  let pad = (4 - bih.biWidth * 3 mod 4) land 3;

  for (y in bih.biHeight - 1 downto 0) {
    for (x in 0 to bih.biWidth - 1) {
      let b = (read_byte(ic) land 0xFF) lsl 16;
      let g = (read_byte(ic) land 0xFF) lsl 8;
      let r = (read_byte(ic) land 0xFF) lsl 0;
      let a = 0xFF lsl 24;
      Array1.set(
        data,
        y * bih.biWidth + x,
        Int32.of_int(a lor b lor g lor r),
      );
    };
    for (_j in 0 to pad - 1) {
      skip_byte(ic);
    };
  };
  data;
};

let load_image32data = (bih, ic) => {
  let data = Array1.create(int32, c_layout, bih.biWidth * bih.biHeight);

  for (y in bih.biHeight - 1 downto 0) {
    for (x in 0 to bih.biWidth - 1) {
      let b = (read_byte(ic) land 0xFF) lsl 16;
      let g = (read_byte(ic) land 0xFF) lsl 8;
      let r = (read_byte(ic) land 0xFF) lsl 0;
      let a = (read_byte(ic) land 0xFF) lsl 24;
      Array1.set(
        data,
        y * bih.biWidth + x,
        Int32.of_int(a lor b lor g lor r),
      );
    };
  };
  data;
};

let load_imagedata = (bih, ic) => {
  switch (bih.biBitCount) {
  | ColorRGBA => load_image32data(bih, ic)
  | ColorRGB => load_image24data(bih, ic)
  | _ => failwith("BMP has to be 32 or 24 bit")
  };
};

let skip_to = (ic, n) => {
  while (bytes_read^ != n) {
    skip_byte(ic);
  };
};

let read_bmp = ic => {
  bytes_read := 0;

  let bmpFileHeader = load_bitmapfileheader(ic);
  let bmpInfoHeader = load_bitmapinfoheader(ic);

  skip_to(ic, bmpFileHeader.bfOffBits);
  let bmpBytes = load_imagedata(bmpInfoHeader, ic);

  {bmpFileHeader, bmpInfoHeader, bmpBytes};
};

let load = filename => {
  let ic = open_in_bin(filename);
  let bmp = read_bmp(ic);
  close_in(ic);

  (bmp.bmpInfoHeader.biWidth, bmp.bmpInfoHeader.biHeight, bmp.bmpBytes);
};
