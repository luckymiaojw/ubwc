//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang magic.jw@magicip.com.cn
// Create Date       : 2026-02-28  03:02:53
// Module Name       : axis_to_txt_writer.sv
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							: 
//  
//////////////////////////////////////////////////////////////////////////////////
//`timescale 1ns/1ps

module axis_to_txt_writer
    #(
        parameter string FILE_NAME = "axis_data_out.txt"
    )(
        input  logic         clk,
        input  logic         rst_n,
        
        // AXI-Stream Interface (Slave)
        input  logic         s_axis_tvalid,
        output logic         s_axis_tready,
        input  logic [255:0] s_axis_tdata,
        input  logic [31:0]  s_axis_tkeep,  // Byte mask (1 bit per byte)
        input  logic         s_axis_tlast
    );

    integer file_handle;
    logic [255:0] masked_data;

    // Always ready to accept data
    assign s_axis_tready = 1'b1; 

    // Initialize: Open the file for writing
    initial begin
        file_handle = $fopen(FILE_NAME, "w");
        if (file_handle == 0) begin
            $display("[ERROR] Could not open file: %s", FILE_NAME);
            $finish;
        end else begin
            $display("[SUCCESS] File opened for writing: %s", FILE_NAME);
        end
    end

    // Combinational logic: Apply mask to data
    // If tkeep[i] is 1, keep original byte; if 0, replace with 8'h00
    always_comb begin
        for (int i = 0; i < 32; i++) begin
            masked_data[i*8 +: 8] = s_axis_tkeep[i] ? s_axis_tdata[i*8 +: 8] : 8'h00;
        end
    end

    // Sequential logic: Write data to file on valid handshake
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // Stay idle during reset
        end else begin
            // Handshake occurs when both tvalid and tready are high
            if (s_axis_tvalid && s_axis_tready) begin
                
                // Chunk 0: Bits [63:0]
                // Write only if at least one byte in this 64-bit chunk is valid
                $fdisplay(file_handle, "%016x%016x%016x%016x",masked_data[255:192],masked_data[191:128],masked_data[127:64],masked_data[63:0]);
            end
        end
    end

    // Simulation Clean-up: Close the file
    final begin
        if (file_handle != 0) begin
            $fclose(file_handle);
            $display("[INFO] File closed successfully: %s", FILE_NAME);
        end
    end

endmodule
