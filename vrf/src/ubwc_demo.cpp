#include <iostream>
#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <iomanip>
#include <svdpi.h>

#define MAX_NUM_PLANES 2

#define FORMAT_RGBA8888        0
#define FORMAT_RGBA1010102     1
#define FORMAT_NV12            2
#define FORMAT_P010            3
#define FORMAT_RGBA8888_L_2_1  4

// Exported SV tasks (declared with export "DPI-C" in testbench_top.sv)
//extern "C" void     sv_enc_process_packed(const svBitVecVal* in_bits, svBitVecVal* out_bits);
//extern "C" void     sv_dec_process_packed(const svBitVecVal* in_bits, svBitVecVal* out_bits);
extern "C" int      ubwc_demo_main(int argc, char** argv); // from ubwc_demo.cpp compiled with -Dmain=ubwc_demo_main
extern "C" int      ubwc_demo_run(int format, int w, int h);
extern "C" int32_t  __wrap_dummy_Encode(uint8_t* linear_data, int32_t meta_flag, uint8_t* encoded_data);
extern "C" void     __wrap_dummy_Decode(uint8_t* compressed_data, int32_t meta_flag, uint8_t* decoded_data);

extern "C" int get_ubwc_addr(int l1, int l2, int l3, int hi_bit, int spread, int f4, int lossy,
                             int pitch, int y, int x,
                             int *addr);

static inline void pack_256bytes_to_2048bits(const uint8_t* in, svBitVecVal* out64words) {
    // 2048 bits => 64 * 32-bit words. LSB is byte0 bit0.
    std::memset(out64words, 0, 64 * sizeof(svBitVecVal));
    for (int i = 0; i < 256; i++) {
        int bitpos = i * 8;
        int w = bitpos / 32;
        int s = bitpos % 32;
        uint32_t v = (uint32_t)in[i];
        out64words[w] |= (v << s);
        if (s > 24) { // spans boundary
            out64words[w+1] |= (v >> (32 - s));
        }
    }
}

static inline void unpack_2048bits_to_256bytes(const svBitVecVal* in64words, uint8_t* out) {
    for (int i = 0; i < 256; i++) {
        int bitpos = i * 8;
        int w = bitpos / 32;
        int s = bitpos % 32;
        uint32_t val = (in64words[w] >> s);
        if (s > 24) {
            val |= (in64words[w+1] << (32 - s));
        }
        out[i] = (uint8_t)(val & 0xFFu);
    }
}

// Linker wrap symbols used inside ubwc_demo.cpp
int32_t __wrap_dummy_Encode(uint8_t* linear_data, int32_t meta_flag, uint8_t* encoded_data) {
    (void)meta_flag;

    svBitVecVal in_bits[64];
    svBitVecVal out_bits[64];

    if (!linear_data || !encoded_data) return 0;

    pack_256bytes_to_2048bits(linear_data, in_bits);
    std::memset(out_bits, 0, sizeof(out_bits));

    // Call into SV; SV task will advance simulation time and drive ubwc_enc_vivo_top
    //sv_enc_process_packed(in_bits, out_bits);

    uint8_t tmp[256];
    unpack_2048bits_to_256bytes(out_bits, tmp);

    // ubwc_demo.cpp expects compressed_size=128 for its placeholder flow; we keep that.
    std::memcpy(encoded_data, tmp, 128);
    return 128;
}

void __wrap_dummy_Decode(uint8_t* compressed_data, int32_t meta_flag, uint8_t* decoded_data) {
    (void)meta_flag;
    if (!compressed_data || !decoded_data) return;
    
    svBitVecVal in_bits[64];
    svBitVecVal out_bits[64];
    
    // ubwc_demo passes compressed buffer; assume at least 128B valid; zero-pad to 256
    uint8_t tmp_in[256];
    std::memset(tmp_in, 0, sizeof(tmp_in));
    std::memcpy(tmp_in, compressed_data, 128);
    
    pack_256bytes_to_2048bits(tmp_in, in_bits);
    std::memset(out_bits, 0, sizeof(out_bits));
    
    // Call into SV; SV task will advance simulation time and drive ubwc_dec_vivo_top
    // sv_dec_process_packed(in_bits, out_bits);
    
    uint8_t tmp_out[256];
    unpack_2048bits_to_256bytes(out_bits, tmp_out);
    std::memcpy(decoded_data, tmp_out, 256);
}

uint32_t size_alignment(uint32_t size, uint32_t size_unit)
{
    uint32_t aligned_size;
    aligned_size = ((size + size_unit - 1) / size_unit) * size_unit;
    return aligned_size;
}

uint32_t programBit(uint32_t bit_index, uint32_t bit_value, uint32_t m_word)
{
    uint32_t m_word_p;
    if (bit_value == 0)
    {
        m_word_p = (~((uint32_t)1 << bit_index)) & m_word;
    }
    else
    {
        m_word_p = ((uint32_t)1 << bit_index) | m_word;
    }
    return m_word_p;
}

uint32_t getBit(uint32_t bit_index, uint32_t m_word)
{
    return (((uint32_t)1 << bit_index) & m_word) != 0 ? 1 : 0;
}

int32_t get_metadata_address(int32_t tile_x, int32_t tile_y, int32_t meta_data_plane_pitch)
{
    int32_t meta_tile_row = tile_y / 16;
    int32_t meta_tile_col = tile_x / 16;
    int32_t meta_tile_sub_tile_row = (tile_y % 16) / 8;
    int32_t meta_tile_sub_tile_col = (tile_x % 16) / 8;
    int32_t meta_data_row_in_sub_tile = (tile_y - meta_tile_row * 16 - meta_tile_sub_tile_row * 8);
    int32_t meta_data_col_in_sub_tile = (tile_x - meta_tile_col * 16 - meta_tile_sub_tile_col * 8);

    int32_t meta_data_address = (meta_tile_row * 16 * meta_data_plane_pitch)
                                + (meta_tile_col * 256)
                                + (meta_tile_sub_tile_row * 128)
                                + (meta_tile_sub_tile_col * 64)
                                + (meta_data_row_in_sub_tile * 8) + meta_data_col_in_sub_tile;

    return meta_data_address;
}

uint64_t get_tile_address(int32_t tile_x, int32_t tile_y, int32_t tile_width, int32_t tile_height,
                          int32_t surface_pitch, int32_t highest_bank_bit, int32_t bpp)
{
    uint64_t macrotiled_address = 0;
    uint32_t lvl2_BankSwizzling_en = 1;
    uint32_t lvl3_BankSwizzling_en = 1;

    int macro_tile_addr_ddr_8_channel[8][8] = {
        {0,6,3,5,4,2,7,1},
        {7,1,4,2,3,5,0,6},
        {10,12,9,15,14,8,13,11},
        {13,11,14,8,9,15,10,12},
        {4,2,7,1,0,6,3,5},
        {3,5,0,6,7,1,4,2},
        {14,8,13,11,10,12,9,15},
        {9,15,10,12,13,11,14,8}
    };

    static const int macro_tile_size = 4096; // 16*256

    int macro_tile_x = tile_x / 4;
    int macro_tile_y = tile_y / 4;
    int temp_tile_x = tile_x % 8;
    int temp_tile_y = tile_y % 8;

    uint64_t macro_tile_base = (uint64_t)surface_pitch * (macro_tile_y * 4) * tile_height + (uint64_t)macro_tile_x * macro_tile_size;
    macrotiled_address = macro_tile_base + (uint64_t)macro_tile_addr_ddr_8_channel[temp_tile_x][temp_tile_y] * 256;

    // Bank Swizzling Level 2
    if (lvl2_BankSwizzling_en)
    {
        if (((16 * surface_pitch) % (1 << highest_bank_bit)) == 0)
        {
            uint32_t bit_val = getBit(highest_bank_bit - 1, (uint32_t)macrotiled_address) ^ 
                              ((((bpp == 1 && tile_width * 4 == 128 && tile_height * 4 == 32) || 
                                 (bpp == 2 && tile_width * 4 == 64  && tile_height * 4 == 32)) 
                                ? getBit(5, tile_y * tile_height) 
                                : getBit(4, tile_y * tile_height)));
            macrotiled_address = programBit(highest_bank_bit - 1, bit_val, (uint32_t)macrotiled_address);
        }
    }

    // Bank Swizzling Level 3
    if (lvl3_BankSwizzling_en)
    {
        if (((16 * surface_pitch) % (1 << (highest_bank_bit + 1))) == 0)
        {
            uint32_t bit_val = getBit(highest_bank_bit, (uint32_t)macrotiled_address) ^ 
                              ((((bpp == 1 && tile_width * 4 == 128 && tile_height * 4 == 32) || 
                                 (bpp == 2 && tile_width * 4 == 64 && tile_height * 4 == 32)) 
                                ? getBit(6, tile_y * tile_height) 
                                : getBit(5, tile_y * tile_height)));
            macrotiled_address = programBit(highest_bank_bit, bit_val, (uint32_t)macrotiled_address);
        }
    }

    return macrotiled_address;
}

int32_t decode_metadata(int format, uint8_t metadata, int32_t& meta_flag)
{
    int compressed_size = 0;
    meta_flag = 0; 

    if ((metadata & 0xC0) != 0) 
    {
        compressed_size = 32;
        meta_flag = 0;
    }
    else if ((metadata & 0x10) == 0) 
    {
        compressed_size = 0;
        meta_flag |= 0x08;
        meta_flag |= ((metadata & 0x0C) >> 1);
    }
    else if ((metadata & 0x10) == 0x10) 
    {
        compressed_size = (((metadata & 0x0E) >> 1) + 1) * 32;
        meta_flag |= ((metadata & 0x0E) >> 1);

        if (compressed_size == 256)
        {
            if (format == FORMAT_RGBA8888)
            {
                uint8_t bit5 = metadata & 0x20;
                uint8_t bit0 = metadata & 0x01;
                uint8_t alpha_mode = (bit5 >> 4) | bit0;
                if (alpha_mode == 2 || alpha_mode == 3)
                {
                    compressed_size = 192;
                }
            }
            else if (format == FORMAT_RGBA8888_L_2_1)
            {
                compressed_size = 128;
            }
        }
    }

    return compressed_size;
}

uint8_t encode_metadata(int format, int32_t compressed_size, int32_t meta_flag)
{
    uint8_t metadata = 0;
    metadata |= ((compressed_size / 32) - 1);
    metadata <<= 1;
    metadata |= 0x10;
    return metadata;
}

int32_t dummy_Encode(uint8_t *linear_data, int32_t meta_flag, uint8_t *encoded_data)
{
    int compressed_size = 0;
    return compressed_size;
}

void dummy_Decode(uint8_t* compressed_data, int32_t meta_flag, uint8_t* decoded_data)
{
    (void)compressed_data;
    (void)meta_flag;
    if (decoded_data != nullptr)
    {
        memset(decoded_data, 0, 256);
    }
}

int ubwc_demo_main(int argc, char** argv)
{
    if (argc < 4)
    {
        std::cerr << "Useage : " << argv[0] << "<Format> <Frame Width> <Frame Height>" << std::endl;
        std::cerr << "Format :  0(RGBA8888),1(RGBA1010102),2(NV12),3(P010),4(RGBA8888_L_2_1)" << std::endl;
        return -1;
    }

    int format = atoi(argv[1]);
    int frame_width = atoi(argv[2]);
    int frame_height = atoi(argv[3]);
    
    if (format < 0 || format > 4)
    {
        std::cerr << "Fatal : (format < 0 || format > 4)" << std::endl;
        return -1;
    }

    if (frame_width <= 0 || frame_height <= 0)
    {
        std::cerr << "Fatal : (frame_width <= 0 || frame_height <= 0)" << std::endl;
        return -1;
    }

    std::cout << "=== Initital Parameter ===" << std::endl;
    std::cout << "Image Format: " << format << std::endl;
    std::cout << "Image Size  : " << frame_width << "x" << frame_height << std::endl;

    int numPlanes = 0;
    int32_t tile_width = 0;
    int32_t tile_height = 0;
    int32_t plane_height[MAX_NUM_PLANES] = {0};
    int bpp = 0;
    int lossy_pcm_mode = 0;

    switch (format)
    {
        case FORMAT_RGBA8888:
        case FORMAT_RGBA8888_L_2_1:
            numPlanes = 1;
            tile_width = 16;
            tile_height = 4;
            plane_height[0] = frame_height;
            bpp = 4;
            break;
        case FORMAT_NV12:
            numPlanes = 2;
            tile_width = 32;
            tile_height = 8;
            bpp = 1;
            plane_height[0] = frame_height;
            plane_height[1] = frame_height >> 1;
            break;
        case FORMAT_RGBA1010102:
            numPlanes = 1;
            tile_width = 16;
            tile_height = 4;
            bpp = 4;
            plane_height[0] = frame_height;
            break;
        case FORMAT_P010:
            numPlanes = 2;
            tile_width = 32;
            tile_height = 4;
            bpp = 2;
            plane_height[0] = frame_height;
            plane_height[1] = frame_height >> 1;
            break;
        default:
            std::cerr << "Unsupported Format" << std::endl;
            return -1;
    }

    int bank_spreading_en = 1;
    int highest_bank_bit = 16;

    std::cout << "\n=== Decode Begin : Read compressed Frame and Decode" << std::endl;
    for (int32_t plane = 0; plane < numPlanes; plane++)
    {
        std::cout << "Plane : " << plane << std::endl;
        std::cout << "\ttile_width : " << tile_width    << std::endl;
        std::cout << "\ttile_height: " << tile_height   << std::endl;
        std::cout << "\tplane_height[" << plane << "]: " << plane_height[plane] << std::endl;

        int numXTiles = (size_alignment(frame_width, tile_width * 4) + tile_width - 1) / tile_width;
        int numYTiles = (size_alignment(plane_height[plane], tile_height * 4) + tile_height - 1) / tile_height;

        std::cout << "\tnumXTiles  : " << numXTiles     << std::endl;
        std::cout << "\tnumYTiles  : " << numYTiles     << std::endl;

        int32_t meta_data_plane_pitch = size_alignment(
            (size_alignment(frame_width, tile_width * 4) + tile_width - 1) / tile_width, 64);
        int32_t surface_pitch = size_alignment(frame_width * bpp, tile_width * 4 * bpp);

        std::cout << "\tmeta_data_plane_pitch: " << meta_data_plane_pitch << std::endl;
        std::cout << "\tsurface_pitch        : " << surface_pitch << std::endl;

        int max_tiles_to_show = 10000;
        int tile_count = 0;

        for (int32_t tile_y = 0; tile_y < numYTiles; tile_y++)
        {
            for (int32_t tile_x = 0; tile_x < numXTiles; tile_x++)
            {
                if ((tile_x * tile_width > frame_width) || (tile_y * tile_height > plane_height[plane]))
                    continue;

                if (tile_count >= max_tiles_to_show)
                    break;
                tile_count++;

                int32_t meta_address = get_metadata_address(tile_x, tile_y, meta_data_plane_pitch);
                std::cout << "\n\tTile(X,Y):( " << tile_x << "," << tile_y << "):" << std::endl;
                std::cout << "\tMETA ADDRESS: " << meta_address << std::endl;

                uint8_t metadata = 0x10;
                int32_t compressed_size = 0;
                int32_t meta_flag = 0;
                
                compressed_size = decode_metadata(format, metadata, meta_flag);
                std::cout << "\tCompressed_size: " << compressed_size << " Bytes" << std::endl;

                uint64_t tile_address = get_tile_address(tile_x, tile_y, tile_width, tile_height,
                                                         surface_pitch, highest_bank_bit, bpp);

                if ((format == FORMAT_RGBA8888_L_2_1) /* && (lossy_pcm_mode == 1) */)
                {
                    bank_spreading_en = 0;
                    tile_address = get_tile_address(tile_x, tile_y / 2, tile_width, tile_height,
                                                     surface_pitch, highest_bank_bit, bpp);
                    tile_address += (128 * (tile_y % 2));
                }

                // Bank Spreading处理
                if (bank_spreading_en)
                {
                    int bank_spreaded = ((tile_address & 0x100) >> 8) ^ ((tile_address & 0x200) >> 9);
                    if (bank_spreaded && (compressed_size <= 128))
                    {
                        tile_address += 0x80;
                    }
                }

                int sv_tile_address =0;
                //get_ubwc_addr(l1, l2, l3, hi_bit, spread, f4, lossy, pitch, y, x, *addr);
                get_ubwc_addr(1,1,1,highest_bank_bit,bank_spreading_en,1,0,
                        surface_pitch,tile_y,tile_x,
                        &sv_tile_address);

                std::cout << "\tTile CPP Address: 0x" << std::hex << tile_address << std::dec << std::endl;
                std::cout << "\tTile SV  Address: 0x" << std::hex << sv_tile_address << std::dec << std::endl;

                if(tile_address != (sv_tile_address << 4))
                {
                    std::cerr << "\tCPP Address != SV Address" << std::endl;
                }

                uint8_t decoded_data[256] = {0};
                dummy_Decode(nullptr, meta_flag, decoded_data);
                std::cout << "\tTile Address Gen Complete" << std::endl;
            }
            if (tile_count >= max_tiles_to_show)
                break;
        }
        std::cout << "Done" << std::endl;
    }

    std::cout << "\n=== Encode Begin：Encode and Compressed ===" << std::endl;
    for (int32_t plane = 0; plane < numPlanes; plane++)
    {
        std::cout << "Plane :" << plane << std::endl;
        std::cout << "\ttile_width : " << tile_width    << std::endl;
        std::cout << "\ttile_height: " << tile_height   << std::endl;
        std::cout << "\tplane_height[" << plane << "]: " << plane_height[plane] << std::endl;

        int numXTiles = (size_alignment(frame_width, tile_width * 4) + tile_width - 1) / tile_width;
        int numYTiles = (size_alignment(plane_height[plane], tile_height * 4) + tile_height - 1) / tile_height;

        std::cout << "\tnumXTiles  : " << numXTiles     << std::endl;
        std::cout << "\tnumYTiles  : " << numYTiles     << std::endl;

        int32_t meta_data_plane_pitch   = size_alignment((size_alignment(frame_width, tile_width * 4) + tile_width - 1) / tile_width, 64);
        int32_t surface_pitch           = size_alignment(frame_width * bpp, tile_width * 4 * bpp);

        std::cout << "\tmeta_data_plane_pitch: " << meta_data_plane_pitch << std::endl;
        std::cout << "\tsurface_pitch        : " << surface_pitch << std::endl;

        int max_tiles_to_show = 10000;
        int tile_count = 0;

        for (int32_t tile_y = 0; tile_y < numYTiles; tile_y++)
        {
            for (int32_t tile_x = 0; tile_x < numXTiles; tile_x++)
            {
                if ((tile_x * tile_width > frame_width) || (tile_y * tile_height > plane_height[plane]))
                    continue;

                if (tile_count >= max_tiles_to_show)
                    break;
                tile_count++;

                uint8_t linear_data[256] = {0};
                uint8_t encoded_data[256] = {0};
                int32_t meta_flag = 0;
                int32_t compressed_size = 0;
                
                compressed_size = dummy_Encode(linear_data, meta_flag, encoded_data);

                std::cout << "\n\tTile(X,Y):( " << tile_x << "," << tile_y << "):" << std::endl;
                std::cout << "\tCompressed Size: " << compressed_size << " Bytes" << std::endl;

                //Calculate Tile Address
                uint64_t tile_address = get_tile_address(tile_x, tile_y, tile_width, tile_height, surface_pitch, highest_bank_bit, bpp);

                if (format == FORMAT_RGBA8888_L_2_1)
                {
                    bank_spreading_en = 0;
                    tile_address = get_tile_address(tile_x, tile_y / 2, tile_width, tile_height,
                                                     surface_pitch, highest_bank_bit, bpp);
                    tile_address += (128 * (tile_y % 2));
                }

                if (bank_spreading_en)
                {
                    int bank_spreaded = ((tile_address & 0x100) >> 8) ^ ((tile_address & 0x200) >> 9);
                    if (bank_spreaded && (compressed_size <= 128))
                    {
                        tile_address += 0x80;
                    }
                }

                int sv_tile_address =0;
                //get_ubwc_addr(l1, l2, l3, hi_bit, spread, f4, lossy, pitch, y, x, *addr);
                get_ubwc_addr(1,1,1,highest_bank_bit,bank_spreading_en,1,0,
                        surface_pitch,tile_y,tile_x,
                        &sv_tile_address);

                std::cout << "\tTile CPP Address: 0x" << std::hex << tile_address << std::dec << std::endl;
                std::cout << "\tTile SV  Address: 0x" << std::hex << sv_tile_address << std::dec << std::endl;

                if(tile_address != (sv_tile_address << 4))
                {
                    std::cerr << "\tCPP Address != SV Address" << std::endl;
                }

                uint8_t metadata    = encode_metadata(format, compressed_size, meta_flag);
                std::cout << "\tMeta Data   : " << " (Hex: 0x" << std::hex << (int)metadata << std::dec << ")" << std::endl;
                int32_t meta_address= get_metadata_address(tile_x, tile_y, meta_data_plane_pitch);
                std::cout << "\tMeta Address: " << " (Hex: 0x" << std::hex << (int)meta_address << std::dec << ")" << std::endl;
            }
            if (tile_count >= max_tiles_to_show)
                break;
        }
    }

    std::cout << "\n=== Done ===" << std::endl;
    return 0;
}

int ubwc_demo_run(int format, int w, int h)
{
    // Build argv: prog format width height
    char a0[] = "ubwc_demo";
    char a1[32], a2[32], a3[32];
    std::snprintf(a1, sizeof(a1), "%d", format);
    std::snprintf(a2, sizeof(a2), "%d", w);
    std::snprintf(a3, sizeof(a3), "%d", h);
    char* argv[] = {a0, a1, a2, a3, nullptr};
    int argc = 4;
    return ubwc_demo_main(argc, argv);
}

