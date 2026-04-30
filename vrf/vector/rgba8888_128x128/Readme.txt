RGBA8888 128x128 generated vector

Format:
  - rgba8888_128x128_linear.memh: 64-bit words, raster scan, two pixels per word
  - rgba8888_128x128_tiled.memh: 64-bit words, compact 16x4 tile scan
  - rgba8888_128x128_tiled_mapped.memh: 64-bit words in UBWC tile-address layout
  - rgba8888_128x128_meta_dummy.memh: dummy metadata for FORCE_FULL_PAYLOAD decoder wrapper runs
  - rgba8888_128x128_expected_otf_stream.txt: 128-bit OTF beats, four pixels per beat

Pixel pattern:
  r = x * 3 + y * 5
  g = x * 7 + y * 11
  b = x * 13 xor y * 17
  a = 0xff
