//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang magic.jw@magicip.com.cn
// Create Date       : 2026-02-27  02:09:29
// Module Name       : testbench_top_apb.sv
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							: 
//  
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps


module testbench_top;

    initial begin
        //if(dump == 1) begin
        $display("Dumping Waveform for DEBUG is active !!!");
        $fsdbAutoSwitchDumpfile(10000,"top.fsdb",20);
        $fsdbDumpfile("top.fsdb");
        $fsdbDumpMDA(0,testbench_top);
        $fsdbDumpSVA(0,testbench_top);
        $fsdbDumpvars(0,testbench_top);
        //end
    end

    `include "dut_conn.sv"

    // DPI entry point
    import "DPI-C" context task ubwc_demo_run(int format, int w, int h);//, string in0);

    initial begin
        int rc;
        int format;
        int w;
        int h;
        string in0;

        format = 0;
        w      = 4096;
        h      = 600;

        wait (rstn == 1);
        $display("[TB] reset done, calling ubwc_run...");
        ubwc_demo_run(format, w, h);//, in0);
        $display("[TB] ubwc_run returned rc=%0d", rc);
    end

endmodule
