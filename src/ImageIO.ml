type 'a img = { width : int; height : int; image : 'a }

exception ImageNotLoaded

module type ImageIO = sig
  type t

  val loadImage : string -> t img
  val makeSameAsLayout : t img -> t img
  val readRawPixelAtOffset : int -> t img -> Int32.t [@@inline.always]
  val readRawPixel : x:int -> y:int -> t img -> Int32.t [@@inline.always]
  val setImgColor : x:int -> y:int -> Int32.t -> t img -> unit
  val saveImage : t img -> string -> unit
  val freeImage : t img -> unit
end
