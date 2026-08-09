`timescale 1ns / 1ps

module v5_bootloader_top (
    input  wire clk,             
    input  wire rst_n,           
    input  wire start_boot,      
    
    output wire [20:0] mram_a,   
    output wire [3:0]  mram_ce_b,
    output wire mram_we,          
    input  wire [7:0]  mram_dq,
    
    output reg  v5_prog_b,
    input  wire v5_done, 
    output wire v5_cclk,
    output wire v5_din,

    output wire dbg_clk_3mhz,
    output wire dbg_dbg_rst_n,
    output wire dbg_byte_pulse 
);

    wire rst;
    wire clk_3MHz; 
    assign rst = ~rst_n;

    reg [1:0] clk_div;
    
    always @(posedge clk or posedge rst) begin
        if (rst) clk_div <= 2'd0;
        else     clk_div <= clk_div + 1'b1;
    end
    assign dbg_clk_3mhz = clk_div[1]; 
    assign clk_3MHz = clk_div[1]; 

    wire [7:0] pipe_data;
    wire       pipe_ready;
    wire       pipe_stall;
    reg        dbg_rst_n; 
    wire       internal_mram_eof; 
    mram_interface mram_inst (
        .clk(clk_3MHz), 
        .rst(rst), 
        .start_config(dbg_rst_n),
        .mram_a(mram_a),
        .mram_ce_b(mram_ce_b),
        .mram_we(mram_we),   
        .mram_dq(mram_dq),
        .tx_buffer_full(pipe_stall), 
        .byte_out(pipe_data), 
        .byte_ready(pipe_ready),
        .mram_eof(internal_mram_eof) 
    );
    piso_serializer piso_inst (
        .clk(clk_3MHz), 
        .rst(rst),
        .byte_in(pipe_data),
        .byte_ready(pipe_ready),
        .tx_buffer_full(pipe_stall),
        .v5_cclk(v5_cclk),
        .v5_din(v5_din),
        .byte_done_pulse(dbg_byte_pulse) // WIRING PISO TO EXTERNAL PIN
    );

//for MRAM Clock Generation after FPGA configured
 STARTUP_VIRTEX5 STARTUP_VIRTEX5_inst(                                                                                                 
            .CFGCLK(), //-- Config logic clock 1-bit output                                          
            .CFGMCLK(),// -- Config internal osc clock 1-bit output                                   
            .DINSPI(), //-- DIN SPI PROM access 1-bit output                                         
            .EOS(), //-- End of Startup 1-bit output                                              
            .TCKSPI(), //-- TCK SPI PROM access 1-bit output                                         
            .CLK(1'b0), //-- Clock input for start-up sequence                                 
            .GSR(1'b0), //-- Global Set/Reset input (GSR cannot be used for the port name)   
            .GTS(1'b0), //-- Global 3-state input (GTS cannot be used for the port name)               
            .USRCCLKO(clk_3MHz), //-- User CCLK 1-bit input                                             
            .USRCCLKTS(1'b0), //-- User CCLK 3-state, 1-bit input                                            
            .USRDONEO(1'b1), //-- User Done 1-bit input                                                     
            .USRDONETS(1'b0) //-- User Done 3-state, 1-bit input                                             
         );
    localparam IDLE         = 2'd0,
               WAIT_BUTTON  = 2'd1,
               STREAM_DATA  = 2'd2,
               WAKEUP_DELAY = 2'd3;

    reg [1:0] state;

    // THE ENVELOPE SIGNAL (SCOPE CH1)
    assign dbg_dbg_rst_n = dbg_rst_n;

    always @(posedge clk_3MHz or posedge rst) begin
        if (rst) begin
            state       <= IDLE;
            v5_prog_b   <= 1'b1; 
            dbg_rst_n <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    v5_prog_b <= 1'b0; 
                    state     <= WAIT_BUTTON;
                end
                
                WAIT_BUTTON: begin
                    if (start_boot == 1'b1) begin
                        v5_prog_b   <= 1'b1; 
                        dbg_rst_n <= 1'b1; 
                        state       <= STREAM_DATA;
                    end
                end
                
                STREAM_DATA: begin
                    if (v5_done == 1'b1 || internal_mram_eof == 1'b1) begin
                        dbg_rst_n <= 1'b0; 
                        state       <= WAKEUP_DELAY;
                    end
                end
                
                WAKEUP_DELAY: begin
                    // Hold state indefinitely
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule

