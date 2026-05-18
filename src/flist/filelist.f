+incdir+../dec
+incdir+../ip/ubwc_x2x/src

-f filelist_ubwc_x2x.f
-f filelist_axi_2t1_int.f

../ip/mg_sync_fifo.v
../dec/ubwc_dec_meta_get_cmd_gen.v
../dec/ubwc_dec_meta_axi_rcmd_gen.v
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
../ip/mg_async_fifo.v
../ip/sram_pdp_8192x128.v
../dec/ubwc_dec_wrapper_top.v

../../vrf/src/dec/tb_axi_read_slave_model.sv
