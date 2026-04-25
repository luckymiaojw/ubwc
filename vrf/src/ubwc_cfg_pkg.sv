//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang magic.jw@magicip.com.cn
// Create Date       : 2026-02-27  06:24:46
// Module Name       : ubwc_cfg_pkg.sv
// Description       : Verification-only UBWC configuration parser using $sscanf
// -------------------------------------------------------------------------------
//////////////////////////////////////////////////////////////////////////////////

package ubwc_cfg_pkg;

    // UBWC configuration struct definition
    typedef struct {
        string       meta_y_file;
        string       comp_y_file;
        string       uncomp_y_file;
        string       linear_file;
        string       image_format;
        int unsigned width;
        int unsigned height;
        int unsigned aligned_h_p0;
        int unsigned pitch_p0;
        int unsigned meta_pitch_p0;
        int unsigned meta_h_p0;
        int unsigned highest_bank_bit;
        int unsigned mal_size;
        int unsigned lvl1_swz;
        int unsigned lvl2_swz;
        int unsigned lvl3_swz;
        int unsigned bank_spread;
        int unsigned amsbc;
        int unsigned lossy;
        int unsigned ddr_channels;
    } ubwc_cfg_t;

    // Trim leading/trailing spaces, tabs, and newlines
    function automatic string _trim(string s);
        int i, j;
        i = 0;
        while (i < s.len() && (s.getc(i) == " " || s.getc(i) == "\t")) i++;
        j = s.len() - 1;
        while (j >= i && (s.getc(j) == " " || s.getc(j) == "\t" || s.getc(j) == "\r" || s.getc(j) == "\n")) j--;
        if (j < i) return "";
        return s.substr(i, j); // Note: for SV substr(i, j), the second argument is the end index
    endfunction

    // Convert a string to an unsigned integer; supports decimal and hexadecimal
    function automatic int unsigned _parse_uint(string s);
        string t; 
        int unsigned v;
        t = _trim(s); 
        v = 0;
        if (t.len() >= 2 && (t.substr(0,1) == "0x" || t.substr(0,1) == "0X")) begin
            void'($sscanf(t, "0x%h", v));
        end else begin
            void'($sscanf(t, "%d", v));
        end
        return v;
    endfunction

    // Main parser function
    function automatic void parse_readme(string path, output ubwc_cfg_t cfg);
        int fd;
        string line, key, val;
        
        // Initialize
        cfg.width            = 0;
        cfg.height           = 0;
        cfg.image_format     = "";

        fd = $fopen(path, "r");
        if (fd == 0) begin
            $fatal(1, "[ubwc_cfg] Cannot open file: %s", path);
        end

        while (!$feof(fd)) begin
            line = "";
            void'($fgets(line, fd));
            line = _trim(line);
            
            if (line.len() == 0) continue;

            // Use $sscanf to directly extract the Key and Value strings
            // %s automatically skips leading spaces and stops at whitespace, making this robust
            if ($sscanf(line, "%s %s", key, val) == 2) begin
                case (key)
                    "Image_Format"      : cfg.image_format     = val;
                    "Width"             : cfg.width            = _parse_uint(val);
                    "Height"            : cfg.height           = _parse_uint(val);
                    "Aligned_Height_P0" : cfg.aligned_h_p0     = _parse_uint(val);
                    "Pitch_P0"          : cfg.pitch_p0         = _parse_uint(val);
                    "Meta_Pitch_P0"     : cfg.meta_pitch_p0    = _parse_uint(val);
                    "Meta_Height_P0"    : cfg.meta_h_p0        = _parse_uint(val);
                    "Highest_Bank_Bit"  : cfg.highest_bank_bit = _parse_uint(val);
                    "Mal_Size"          : cfg.mal_size         = _parse_uint(val);
                    "Bank_Swizzle_L1"   : cfg.lvl1_swz         = _parse_uint(val);
                    "Bank_Swizzle_L2"   : cfg.lvl2_swz         = _parse_uint(val);
                    "Bank_Swizzle_L3"   : cfg.lvl3_swz         = _parse_uint(val);
                    "Bank_Spread"       : cfg.bank_spread      = _parse_uint(val);
                    "AMSBC"             : cfg.amsbc            = _parse_uint(val);
                    "Lossy"             : cfg.lossy            = _parse_uint(val);
                    "DDR_Channel"       : cfg.ddr_channels     = _parse_uint(val);
                    default: ; // Ignore unknown keys
                endcase
            end
        end

        $fclose(fd);

        // Print parsed results for checking
        $display("-----------------------------------------------");
        $display("UBWC Configuration Parsed From: %s", path);
        $display("Format     : %s", cfg.image_format);
        $display("Resolution : %0d x %0d", cfg.width, cfg.height);
        $display("Pitch      : %0d (Meta: %0d)", cfg.pitch_p0, cfg.meta_pitch_p0);
        $display("DDR Chans  : %0d", cfg.ddr_channels);
        $display("-----------------------------------------------");
    endfunction

endpackage
