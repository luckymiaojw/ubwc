+incdir+../enc
+incdir+../ip/ubwc_x2x/src

-f filelist_ubwc_x2x.f
-f filelist_axi_2t1_int.f

../ip/mg_sync_fifo.v
../ip/mg_async_fifo.v
../ip/ubwc_axi_wr_64to256.v
../ip/ubwc_sram_1rw.v
../enc/ubwc_enc_apb_reg_blk.v
../enc/ubwc_enc_otf_data_packer.v
../enc/ubwc_enc_line_to_tile.v
../enc/ubwc_enc_otf_to_tile_top.v
../enc/ubwc_enc_tileaddr.sv
../enc/ubwc_enc_vivo_top.sv
../enc/ubwc_enc_meta_addr_gen.sv
../enc/ubwc_tile_enc_axi_wcmd_gen.v
../enc/ubwc_enc_meta_axi_wcmd_gen.v
../enc/ubwc_enc_status.v
../enc/ubwc_enc_wrapper_top.sv
../../vrf/src/otf_master_driver.sv
