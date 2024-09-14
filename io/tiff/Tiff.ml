open Bigarray
open Odiff.ImageIO

type data = (int32, int32_elt, c_layout) Array1.t

module IO : ImageIO = struct
  type buffer
  type t = { data : data }

  let loadImage filename : t Odiff.ImageIO.img =
    let width, height, data = ReadTiff.load filename in
    { width; height; image = { data } }

  let readRawPixel ~x ~y img =
    (Array1.unsafe_get img.image.data ((y * img.width) + x) [@inline.always])

  let readRawPixelAtOffset offset img = Array1.unsafe_get img.image.data offset
  [@@inline.always]

  let setImgColor ~x ~y color (img : t Odiff.ImageIO.img) =
    Array1.unsafe_set img.image.data ((y * img.width) + x) color

  let saveImage (img : t Odiff.ImageIO.img) filename =
    WritePng.write_png_bigarray filename img.image.data img.width img.height

  let freeImage (img : t Odiff.ImageIO.img) = ()

  let makeSameAsLayout (img : t Odiff.ImageIO.img) =
    let data = Array1.create int32 c_layout (Array1.dim img.image.data) in
    { img with image = { data } }
end
