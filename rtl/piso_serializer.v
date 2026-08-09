`timescale 1ns / 1ps
module piso_serializer (
    input  wire clk,            // 100 MHz Master
    input  wire rst,
    input  wire [7:0] byte_in,
    input  wire byte_ready,
    output wire tx_buffer_full,
    output reg  v5_cclk,        // True 50 MHz Gated Clock
    output reg  v5_din,
    output reg byte_done_pulse
);

    reg [7:0] shadow_buffer;
    reg       shadow_valid;
    reg [7:0] shift_reg;
    reg [2:0] bit_cnt;
    reg       is_shifting;
    reg       phase;            // 0 = Drive Data (Low CCLK), 1 = Sample Data (High CCLK)

    assign tx_buffer_full = shadow_valid;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            shadow_buffer     <= 8'h00;
            shadow_valid      <= 1'b0;
            shift_reg         <= 8'h00;
            bit_cnt           <= 3'd0;
            is_shifting       <= 1'b0;
            phase             <= 1'b0;
            v5_cclk           <= 1'b0; 
            v5_din            <= 1'b0;
				byte_done_pulse   <= 1'b0;
        end else begin
            byte_done_pulse   <= 1'b0;
            // 1. THE INTAKE (Catches data instantly from MRAM)
            if (byte_ready && !shadow_valid) begin
                shadow_buffer <= byte_in;
                shadow_valid  <= 1'b1;
            end

            // 2. THE EXHAUST (True 50 MHz Phase-Locked Engine)
            if (is_shifting) begin
                
                if (phase == 1'b0) begin
                    // PHASE 0: The Falling Edge. 
                    // Safe to change data while Virtex-5 clock is low.
                    v5_cclk   <= 1'b0;
                    v5_din    <= shift_reg[7];
                    shift_reg <= {shift_reg[6:0], 1'b0};
                    phase     <= 1'b1;
                end 
                else begin
                    // PHASE 1: The Rising Edge.
                    // Virtex-5 physically samples v5_din right now.
                    v5_cclk <= 1'b1;
                    phase   <= 1'b0;
                    
                    if (bit_cnt == 3'd7) begin
								byte_done_pulse <= 1'b1;
                        // Byte is complete. Check if the shadow buffer has the NEXT byte.
                        if (shadow_valid) begin
                            // SEAMLESS HANDOFF: Load next byte instantly to maintain 100% bandwidth.
                            shift_reg    <= shadow_buffer;
                            shadow_valid <= 1'b0;
                            bit_cnt      <= 3'd0;
                            // is_shifting remains 1, phase naturally rolls over to 0 next tick.
                        end else begin
                            is_shifting <= 1'b0; // Pipeline starved. Shut down.
                        end
                    end else begin
                        bit_cnt <= bit_cnt + 1'b1;
                    end
                end
                
            end 
            else if (shadow_valid) begin
                // WAKING UP FROM IDLE
                shift_reg    <= shadow_buffer;
                shadow_valid <= 1'b0;
                is_shifting  <= 1'b1;
                bit_cnt      <= 3'd0;
                phase        <= 1'b0; 
                v5_cclk      <= 1'b0; // Ensure clock is clamped before shifting begins
            end 
            else begin
                // THE DEAD GAP (Gated Clock)
                // If pipeline is starved, clock stays parked Low. Zero false edges.
                v5_cclk <= 1'b0; 
            end
            
        end
    end
endmodule

