+incdir+../dec_rotation
+incdir+../ip/ubwc_x2x/src
+define+UBWC_DEC_ROTATION

-f filelist_ubwc_x2x.f
-f filelist_axi_2t1_int.f

../ip/mg_sync_fifo.v
../ip/mg_async_fifo.v
../ip/sram_pdp_8192x128.v
../dec_rotation/ubwc_sync_sram_fifo.v
../dec_rotation/ubwc_dec_meta_blk_get_cmd_gen.v
../dec_rotation/ubwc_dec_meta_fifo16_rcmd_gen.v
../dec_rotation/ubwc_dec_apb_reg_blk.v
../dec_rotation/ubwc_dec_meta_data_gen.v
../dec_rotation/ubwc_dec_meta_data_decode.v
../dec_rotation/ubwc_dec_status.v
../dec_rotation/ubwc_tileaddr.v
../dec_rotation/ubwc_dec_tile_arcmd_gen.v
../dec_rotation/ubwc_dec_vivo_top.v
../dec_rotation/ubwc_dec_tile_to_otf_rotate.v
../dec_rotation/ubwc_dec_tile_to_otf.v
../dec_rotation/ubwc_dec_tile_to_line_writer.v
../dec_rotation/ubwc_dec_tile_to_line_sram_fetcher.v
../dec_rotation/ubwc_dec_otf_driver.v
../dec_rotation/ubwc_dec_wrapper_top.v

../../vrf/src/dec/tb_axi_read_slave_model.sv
