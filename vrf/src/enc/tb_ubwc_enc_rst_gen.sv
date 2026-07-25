`timescale 1ns/1ps

module tb_ubwc_enc_rst_gen;

    reg                                             i_axi_clk                       ;
    reg                                             i_otf_clk                       ;
    reg                                             i_vivo_clk                      ;
    reg                                             i_axi_rstn                      ;
    reg                                             i_otf_rstn                      ;
    reg                                             i_vivo_rstn                     ;
    reg                                             i_enc_ubwc_en                   ;
    reg                                             i_otf_vsync                     ;
    reg                                             i_frame_cfg_valid               ;
    reg                                             i_axi_idle                      ;
    reg                                             i_error_clear                   ;

    wire                                            o_axi_rstn                      ;
    wire                                            o_otf_rstn                      ;
    wire                                            o_vivo_rstn                     ;
    wire                                            o_axi_drain_req                 ;
    wire                                            o_axi_drain_timeout             ;
    wire                                            o_otf_input_enable              ;
    wire                                            o_otf_frame_start_pulse         ;
    wire                                            o_frame_start_pulse             ;

    integer                                         timeout_count                   ;
    reg                                             saw_axi_reset                   ;
    reg                                             saw_otf_reset                   ;
    reg                                             saw_vivo_reset                  ;
    reg                                             saw_start_pulse                 ;

    task automatic wait_all_released;
        begin
            timeout_count = 0;
            while (!(o_axi_rstn && o_otf_rstn && o_vivo_rstn)) begin
                @(posedge i_axi_clk);
                timeout_count = timeout_count + 1;
                if (timeout_count > 200)
                    $fatal(1, "Timeout waiting for all reset domains to release");
            end
        end
    endtask

    task automatic wait_otf_input_enabled;
        begin
            timeout_count = 0;
            while (!o_otf_input_enable) begin
                @(posedge i_otf_clk);
                timeout_count = timeout_count + 1;
                if (timeout_count > 40)
                    $fatal(1, "Timeout waiting for OTF input enable");
            end
        end
    endtask

    task automatic check_full_soft_reset;
        begin
            saw_axi_reset   = 1'b0;
            saw_otf_reset   = 1'b0;
            saw_vivo_reset  = 1'b0;
            saw_start_pulse = 1'b0;
            timeout_count   = 0;
            while (!saw_start_pulse) begin
                @(posedge i_axi_clk);
                saw_axi_reset   = saw_axi_reset | !o_axi_rstn;
                saw_otf_reset   = saw_otf_reset | !o_otf_rstn;
                saw_vivo_reset  = saw_vivo_reset | !o_vivo_rstn;
                saw_start_pulse = saw_start_pulse | o_frame_start_pulse;
                timeout_count   = timeout_count + 1;
                if (timeout_count > 300)
                    $fatal(1, "Timeout waiting for full soft-reset sequence");
            end
            if (!(saw_axi_reset && saw_otf_reset && saw_vivo_reset))
                $fatal(1, "Soft reset did not reset every clock domain");
            wait_all_released();
            wait_otf_input_enabled();
        end
    endtask

    task automatic check_blocked_soft_reset;
        begin
            saw_axi_reset   = 1'b0;
            saw_otf_reset   = 1'b0;
            saw_vivo_reset  = 1'b0;
            saw_start_pulse = 1'b0;
            timeout_count   = 0;
            while (!saw_start_pulse) begin
                @(posedge i_axi_clk);
                saw_axi_reset   = saw_axi_reset | !o_axi_rstn;
                saw_otf_reset   = saw_otf_reset | !o_otf_rstn;
                saw_vivo_reset  = saw_vivo_reset | !o_vivo_rstn;
                saw_start_pulse = saw_start_pulse | o_frame_start_pulse;
                timeout_count   = timeout_count + 1;
                if (timeout_count > 300)
                    $fatal(1, "Timeout waiting for blocked soft-reset sequence");
            end
            if (!(saw_axi_reset && saw_otf_reset && saw_vivo_reset))
                $fatal(1, "Blocked frame did not reset every clock domain");
            wait_all_released();
            repeat (12) @(posedge i_otf_clk);
            if (o_otf_input_enable)
                $fatal(1, "Invalid frame configuration enabled OTF input");
        end
    endtask

    task automatic pulse_vsync;
        begin
            @(negedge i_otf_clk);
            i_otf_vsync = 1'b1;
            @(negedge i_otf_clk);
            i_otf_vsync = 1'b0;
        end
    endtask

    task automatic check_axi_drain_before_reset;
        begin
            i_axi_idle = 1'b0;
            pulse_vsync();

            timeout_count = 0;
            while (!o_axi_drain_req) begin
                @(posedge i_axi_clk);
                timeout_count = timeout_count + 1;
                if (timeout_count > 20)
                    $fatal(1, "Timeout waiting for AXI drain request");
            end

            repeat (4) @(posedge i_otf_clk);
            if (o_otf_input_enable)
                $fatal(1, "OTF input remained enabled during AXI drain");

            repeat (12) begin
                @(posedge i_axi_clk);
                if (!o_axi_rstn || !o_otf_rstn || !o_vivo_rstn)
                    $fatal(1, "Global reset asserted before AXI writes drained");
                if (o_frame_start_pulse)
                    $fatal(1, "Frame start released before AXI writes drained");
            end

            i_axi_idle = 1'b1;
            check_full_soft_reset();
        end
    endtask

    task automatic check_disable_drain_before_reset;
        begin
            i_axi_idle = 1'b0;
            @(negedge i_axi_clk);
            i_enc_ubwc_en = 1'b0;

            timeout_count = 0;
            while (!o_axi_drain_req) begin
                @(posedge i_axi_clk);
                timeout_count = timeout_count + 1;
                if (timeout_count > 20)
                    $fatal(1, "Timeout waiting for disable AXI drain request");
            end

            repeat (12) begin
                @(posedge i_axi_clk);
                if (!o_axi_rstn || !o_otf_rstn || !o_vivo_rstn)
                    $fatal(1, "Disable reset asserted before AXI writes drained");
            end

            i_axi_idle = 1'b1;
            timeout_count = 0;
            while (o_axi_rstn || o_otf_rstn || o_vivo_rstn) begin
                @(posedge i_axi_clk);
                timeout_count = timeout_count + 1;
                if (timeout_count > 100)
                    $fatal(1, "Disable did not reset every clock domain");
            end

            @(negedge i_axi_clk);
            i_enc_ubwc_en = 1'b1;
            wait_all_released();
            if (o_otf_input_enable)
                $fatal(1, "OTF input enabled after re-enable without VSYNC");
            pulse_vsync();
            check_full_soft_reset();
        end
    endtask

    task automatic check_drain_timeout_does_not_reset;
        begin
            i_axi_idle = 1'b0;
            pulse_vsync();

            while (!o_axi_drain_req)
                @(posedge i_axi_clk);

            repeat (65540) @(posedge i_axi_clk);
            if (!o_axi_drain_timeout)
                $fatal(1, "AXI drain timeout status was not reported");
            if (!o_axi_rstn || !o_otf_rstn || !o_vivo_rstn)
                $fatal(1, "AXI drain timeout bypassed the write-drain requirement");

            i_axi_idle = 1'b1;
            check_full_soft_reset();

            @(negedge i_axi_clk);
            i_error_clear = 1'b1;
            @(negedge i_axi_clk);
            i_error_clear = 1'b0;
            @(posedge i_axi_clk);
            if (o_axi_drain_timeout)
                $fatal(1, "AXI drain timeout status did not clear");
        end
    endtask

    initial begin
        i_axi_clk = 1'b0;
        forever #5 i_axi_clk = ~i_axi_clk;
    end

    initial begin
        i_otf_clk = 1'b0;
        forever #2 i_otf_clk = ~i_otf_clk;
    end

    initial begin
        i_vivo_clk = 1'b0;
        forever #3 i_vivo_clk = ~i_vivo_clk;
    end

    initial begin
        i_axi_rstn       = 1'b0;
        i_otf_rstn       = 1'b0;
        i_vivo_rstn      = 1'b0;
        i_enc_ubwc_en    = 1'b1;
        i_otf_vsync      = 1'b0;
        i_frame_cfg_valid = 1'b1;
        i_axi_idle       = 1'b1;
        i_error_clear    = 1'b0;

        repeat (4) @(posedge i_axi_clk);
        i_axi_rstn  = 1'b1;
        i_otf_rstn  = 1'b1;
        i_vivo_rstn = 1'b1;
        wait_all_released();
        repeat (8) @(posedge i_otf_clk);
        if (o_otf_input_enable)
            $fatal(1, "OTF input enabled before the first VSYNC");
        pulse_vsync();
        check_full_soft_reset();

        i_frame_cfg_valid = 1'b0;
        pulse_vsync();
        check_blocked_soft_reset();
        i_frame_cfg_valid = 1'b1;
        repeat (12) @(posedge i_otf_clk);
        if (o_otf_input_enable)
            $fatal(1, "Late configuration enabled the current frame");
        pulse_vsync();
        check_full_soft_reset();

        i_axi_rstn = 1'b0;
        #1;
        if (o_axi_rstn || o_otf_rstn || o_vivo_rstn || o_otf_input_enable)
            $fatal(1, "i_axi_rstn did not reset the complete chain");
        repeat (2) @(posedge i_axi_clk);
        i_axi_rstn = 1'b1;
        wait_all_released();
        if (o_otf_input_enable)
            $fatal(1, "OTF input enabled after reset without VSYNC");
        pulse_vsync();
        check_full_soft_reset();

        i_otf_rstn = 1'b0;
        #1;
        if (o_axi_rstn || o_otf_rstn || o_vivo_rstn || o_otf_input_enable)
            $fatal(1, "i_otf_rstn did not reset the complete chain");
        repeat (2) @(posedge i_otf_clk);
        i_otf_rstn = 1'b1;
        wait_all_released();
        if (o_otf_input_enable)
            $fatal(1, "OTF input enabled after reset without VSYNC");
        pulse_vsync();
        check_full_soft_reset();

        i_vivo_rstn = 1'b0;
        #1;
        if (o_axi_rstn || o_otf_rstn || o_vivo_rstn || o_otf_input_enable)
            $fatal(1, "i_vivo_rstn did not reset the complete chain");
        repeat (2) @(posedge i_vivo_clk);
        i_vivo_rstn = 1'b1;
        wait_all_released();
        if (o_otf_input_enable)
            $fatal(1, "OTF input enabled after reset without VSYNC");
        pulse_vsync();
        check_full_soft_reset();

        check_axi_drain_before_reset();
        check_disable_drain_before_reset();
        check_drain_timeout_does_not_reset();

        if (o_axi_drain_timeout)
            $fatal(1, "Unexpected AXI drain timeout");

        $display("PASS: all ENC reset sources reset AXI/OTF/VIVO domains");
        $finish;
    end

    ubwc_enc_rst_gen u_dut
    (
        .i_axi_clk                       ( i_axi_clk                       ),
        .i_otf_clk                       ( i_otf_clk                       ),
        .i_vivo_clk                      ( i_vivo_clk                      ),
        .i_axi_rstn                      ( i_axi_rstn                      ),
        .i_otf_rstn                      ( i_otf_rstn                      ),
        .i_vivo_rstn                     ( i_vivo_rstn                     ),
        .i_enc_ubwc_en                   ( i_enc_ubwc_en                   ),
        .i_otf_vsync                     ( i_otf_vsync                     ),
        .i_frame_cfg_valid               ( i_frame_cfg_valid               ),
        .i_axi_idle                      ( i_axi_idle                      ),
        .i_error_clear                   ( i_error_clear                   ),
        .o_axi_rstn                      ( o_axi_rstn                      ),
        .o_otf_rstn                      ( o_otf_rstn                      ),
        .o_vivo_rstn                     ( o_vivo_rstn                     ),
        .o_axi_drain_req                 ( o_axi_drain_req                 ),
        .o_axi_drain_timeout             ( o_axi_drain_timeout             ),
        .o_otf_input_enable              ( o_otf_input_enable              ),
        .o_otf_frame_start_pulse         ( o_otf_frame_start_pulse         ),
        .o_frame_start_pulse             ( o_frame_start_pulse             )
    );

endmodule
