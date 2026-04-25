module axi_stream_txt_reader
#(
    parameter string FILE_PATH = "visual_from_mdss_writeback_4_wb_2_rec_0_verify_ubwc_enc_in0.txt",
    parameter int DATA_WIDTH = 256
)(
    input  logic                   clk,
    input  logic                   rst_n,
    
    input  logic                   m_axis_ready,
    output logic                   m_axis_valid,
    output logic [DATA_WIDTH-1:0]  m_axis_data,
    output logic [(DATA_WIDTH/8)-1:0] m_axis_keep,
    output logic                   m_axis_last
);

    logic [63:0] buffer [0:2**26]; 
    int total_lines = 0;
    int current_ptr = 0;
    int remaining = 0;

    // 1. Improved file-read logic
    initial begin
        int f;
        int status;
        string s_tmp;
        
        $display("Begin Open file:");
        $display("Open file: %s", FILE_PATH);
        $display("End Open file:");

        f = $fopen(FILE_PATH, "r");
        if (f == 0) begin
            $display("--- ERROR ---: Cannot open file: %s", FILE_PATH);
            $finish;
        end

        while (!$feof(f)) begin
            // Probe the next token
            status = $fscanf(f, " %s", s_tmp); // Read one string and automatically skip whitespace
            if (status == 1) begin
                // Skip address lines that start with @
                if (s_tmp.len() > 0 && s_tmp[0] == "@") begin
                    $display("Skipping address line: %s", s_tmp);
                end else begin
                    // Try to parse as hexadecimal
                    if ($sscanf(s_tmp, "%h", buffer[total_lines]) == 1) begin
                        // --- Endianness fix (optional) ---
                        // If the data appears reversed, uncomment the line below
                        // buffer[total_lines] = {<<8{buffer[total_lines]}}; 
                        total_lines++;
                    end
                end
            end
        end
        $fclose(f);
        $display("--- INFO ---: Finished reading file. Total valid lines: %0d", total_lines);
    end

    // 2. Send logic (keeps the original behavior and adds safety checks)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axis_valid <= 1'b0;
            m_axis_last  <= 1'b0;
            current_ptr  <= 0;
            m_axis_data  <= '0;
            m_axis_keep  <= '0;
            remaining   <= total_lines;
        end else begin
            if (m_axis_ready || !m_axis_valid) begin
                if (current_ptr < total_lines) begin
                    remaining = total_lines - current_ptr;
                    m_axis_valid <= 1'b1;
                    m_axis_data  <= '0;
                    m_axis_keep  <= '0;

                    for (int i = 0; i < 4; i++) begin
                        if (i < remaining) begin
                            // Fill the 64-bit segment within the 256-bit word
                            m_axis_data[i*64 +: 64] <= buffer[current_ptr + i];
                            m_axis_keep[i*8 +: 8]   <= 8'hFF;
                        end
                    end

                    if (remaining <= 4) begin
                        m_axis_last <= 1'b1;
                        current_ptr <= total_lines; 
                    end else begin
                        m_axis_last <= 1'b0;
                        current_ptr <= current_ptr + 4;
                    end
                end else begin
                    m_axis_valid <= 1'b0;
                    m_axis_last  <= 1'b0;
                end
            end
        end
    end
endmodule
