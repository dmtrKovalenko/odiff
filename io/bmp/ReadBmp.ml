open Bigarray

type bicompression = BI_RGB | BI_RLE8 | BI_RLE4 | BI_BITFIELDS
type bibitcount = Monochrome | Color16 | Color256 | ColorRGB | ColorRGBA

type bitmapfileheader = {
  bfType : int;
  bfSize : int;
  bfReserved1 : int;
  bfReserved2 : int;
  bfOffBits : int;
}

type bitmapinfoheader = {
  biSize : int;
  biWidth : int;
  biHeight : int;
  biPlanes : int;
  biBitCount : bibitcount;
  biCompression : bicompression;
  biSizeImage : int;
  biXPelsPerMeter : int;
  biYPelsPerMeter : int;
  biClrUsed : int;
  biClrImportant : int;
}

type bmp = {
  bmpFileHeader : bitmapfileheader;
  bmpInfoHeader : bitmapinfoheader;
  bmpBytes : (int32, Bigarray.int32_elt, Bigarray.c_layout) Bigarray.Array1.t;
}

let bytes_read = ref 0

let read_byte ic =
  incr bytes_read;
  input_byte ic

let skip_byte ic =
  incr bytes_read;
  ignore (input_byte ic)

let read_16bit ic =
  let b0 = read_byte ic in
  let b1 = read_byte ic in
  (b1 lsl 8) + b0

let read_32bit ic =
  let b0 = read_byte ic in
  let b1 = read_byte ic in
  let b2 = read_byte ic in
  let b3 = read_byte ic in
  (b3 lsl 24) + (b2 lsl 16) + (b1 lsl 8) + b0

let read_bit_count ic =
  match read_16bit ic with
  | 1 -> Monochrome
  | 4 -> Color16
  | 8 -> Color256
  | 24 -> ColorRGB
  | 32 -> ColorRGBA
  | n -> failwith ("invalid number of colors in bitmap: " ^ string_of_int n)

let read_compression ic =
  match read_32bit ic with
  | 0 -> BI_RGB
  | 1 -> BI_RLE8
  | 2 -> BI_RLE4
  | 3 -> BI_BITFIELDS
  | n -> failwith ("invalid compression: " ^ string_of_int n)

let load_bitmapfileheader ic =
  let bfType = read_16bit ic in
  if bfType <> 19778 then failwith "Invalid bitmap file";
  let bfSize = read_32bit ic in
  let bfReserved1 = read_16bit ic in
  let bfReserved2 = read_16bit ic in
  let bfOffBits = read_32bit ic in
  { bfType; bfSize; bfReserved1; bfReserved2; bfOffBits }

let load_bitmapinfoheader ic =
  try
    let biSize = read_32bit ic in
    let biWidth = read_32bit ic in
    let biHeight = read_32bit ic in
    let biPlanes = read_16bit ic in
    let biBitCount = read_bit_count ic in
    let biCompression = read_compression ic in
    let biSizeImage = read_32bit ic in
    let biXPelsPerMeter = read_32bit ic in
    let biYPelsPerMeter = read_32bit ic in
    let biClrUsed = read_32bit ic in
    let biClrImportant = read_32bit ic in
    {
      biSize;
      biWidth;
      biHeight;
      biPlanes;
      biBitCount;
      biCompression;
      biSizeImage;
      biXPelsPerMeter;
      biYPelsPerMeter;
      biClrUsed;
      biClrImportant;
    }
  with Failure s as e ->
    prerr_endline s;
    raise e

let load_image24data bih ic =
  let data = Array1.create int32 c_layout (bih.biWidth * bih.biHeight) in
  let pad = (4 - (bih.biWidth * 3 mod 4)) land 3 in
  for y = bih.biHeight - 1 downto 0 do
    for x = 0 to bih.biWidth - 1 do
      let b = (read_byte ic land 255) lsl 16 in
      let g = (read_byte ic land 255) lsl 8 in
      let r = (read_byte ic land 255) lsl 0 in
      let a = 255 lsl 24 in
      Array1.set data
        ((y * bih.biWidth) + x)
        (Int32.of_int (a lor b lor g lor r))
    done;
    for _j = 0 to pad - 1 do
      skip_byte ic
    done
  done;
  data

let load_image32data bih ic =
  let data = Array1.create int32 c_layout (bih.biWidth * bih.biHeight) in
  for y = bih.biHeight - 1 downto 0 do
    for x = 0 to bih.biWidth - 1 do
      let b = (read_byte ic land 255) lsl 16 in
      let g = (read_byte ic land 255) lsl 8 in
      let r = (read_byte ic land 255) lsl 0 in
      let a = (read_byte ic land 255) lsl 24 in
      Array1.set data
        ((y * bih.biWidth) + x)
        (Int32.of_int (a lor b lor g lor r))
    done
  done;
  data

let load_imagedata bih ic =
  match bih.biBitCount with
  | ColorRGBA -> load_image32data bih ic
  | ColorRGB -> load_image24data bih ic
  | _ -> failwith "BMP has to be 32 or 24 bit"

let skip_to ic n =
  while !bytes_read <> n do
    skip_byte ic
  done

let read_bmp ic =
  bytes_read := 0;
  let bmpFileHeader = load_bitmapfileheader ic in
  let bmpInfoHeader = load_bitmapinfoheader ic in
  skip_to ic bmpFileHeader.bfOffBits;
  let bmpBytes = load_imagedata bmpInfoHeader ic in
  { bmpFileHeader; bmpInfoHeader; bmpBytes }

let load filename =
  let ic = open_in_bin filename in
  let bmp = read_bmp ic in
  close_in ic;
  (bmp.bmpInfoHeader.biWidth, bmp.bmpInfoHeader.biHeight, bmp.bmpBytes)
