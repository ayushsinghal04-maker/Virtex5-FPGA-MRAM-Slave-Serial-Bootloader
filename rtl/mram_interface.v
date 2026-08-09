`timescale 1ns / 1ps
module mram_interface (
    input  wire clk,
    input  wire rst,
    input  wire start_config,
    
    output reg  [20:0] mram_a,
    output reg  [3:0]  mram_ce_b,
    output wire mram_we,
    input  wire [7:0]  mram_dq,
    
    input  wire tx_buffer_full,
    output reg  [7:0]  byte_out,
    output reg  byte_ready,
    output reg  mram_eof      
);

    assign mram_we = 1'b0;

    localparam IDLE       = 2'd0,
               S_PRIME    = 2'd1,
               S_STREAM   = 2'd2,
               S_WAIT_ACK = 2'd3;

    reg [1:0]  state;
    reg [22:0] sys_addr; 
    reg active_mission;
    
    wire [22:0] next_addr = sys_addr + 1'b1; 

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state           <= IDLE;
            sys_addr        <= 23'd0;
            mram_a          <= 21'd0;
            mram_ce_b       <= 4'b1111;
            byte_ready      <= 1'b0;
            byte_out        <= 8'h00;
            active_mission  <= 1'b0;
            mram_eof        <= 1'b0;
        end else begin
            byte_ready <= 1'b0; 
            mram_eof   <= 1'b0; 

            if (start_config && !active_mission) begin
                active_mission <= 1'b1;
                sys_addr       <= 23'd0;
                state          <= S_PRIME;
            end 
            else if (active_mission) begin
                case (state)
                    
                    S_PRIME: begin
                        mram_a    <= sys_addr[20:0]; 
                        mram_ce_b <= 4'b1110;        
                        state     <= S_STREAM;
                    end

                    S_STREAM: begin
                        if (!tx_buffer_full) begin
                            
                            byte_out   <= mram_dq;             
                            byte_ready <= 1'b1;              
                            
                            if (sys_addr == 23'h7FFFFF) begin
                                active_mission <= 1'b0;
                                mram_ce_b      <= 4'b1111;
                                mram_eof       <= 1'b1; 
                                state          <= IDLE;
                            end else begin
                                mram_a <= next_addr[20:0];
                                
                                case (next_addr[22:21])
                                    2'b00: mram_ce_b <= 4'b1110; 
                                    2'b01: mram_ce_b <= 4'b1101; 
                                    2'b10: mram_ce_b <= 4'b1011; 
                                    2'b11: mram_ce_b <= 4'b0111; 
                                endcase
                                
                                sys_addr <= next_addr;
                                state    <= S_WAIT_ACK; 
                            end
                        end
                    end

                    S_WAIT_ACK: begin
                        if (tx_buffer_full == 1'b1) begin
                            state <= S_STREAM;
                        end
                    end
                endcase
            end
        end
    end
endmodule

