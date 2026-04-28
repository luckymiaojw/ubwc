+incdir+../dec
+incdir+../ip/axi_2t1_int/src
+incdir+../ip/ubwc_x2x/src

-f filelist_axi_2t1_int.f
-f filelist_ubwc_x2x.f

../ip/mg_sync_fifo.v
../dec/ubwc_meta_simple_fifo.v
../dec/ubwc_dec_meta_get_cmd_gen.v
../dec/ubwc_dec_meta_axi_rcmd_gen.v
../dec/ubwc_dec_meta_axi_rdata_to_sram.v
../dec/ubwc_dec_meta_data_from_sram.v
../ip/ubwc_std_single_port_sram.v
../dec/ubwc_dec_meta_pingpong_sram.v
../dec/ubwc_dec_rstn_gen.v
../dec/ubwc_dec_apb_reg_blk.v
../dec/ubwc_dec_meta_data_gen.v
../dec/ubwc_dec_meta_data_decode.v
../dec/ubwc_dec_status.v
../dec/ubwc_tileaddr.v
../dec/ubwc_dec_tile_arcmd_gen.v
../dec/ubwc_dec_vivo_top.v
../dec/ubwc_dec_tile_to_otf.v
../dec/ubwc_dec_tile_to_line_writer.v
../dec/ubwc_dec_tile_to_line_sram_fetcher.v
../dec/ubwc_dec_otf_driver.v
../ip/async_fifo_fwft_256w.v
../ip/sram_pdp_8192x128.v
../dec/ubwc_dec_wrapper_top.v

../../vrf/src/dec/tb_axi_read_slave_model.sv
