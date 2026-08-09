`timescale 1ns / 1ps
module tb_v5_bootloader;
    // Inputs
    reg clk;
    reg rst_n;
    reg start_boot;
    reg v5_done;

    // Outputs
    wire [20:0] mram_a;
    wire [3:0]  mram_ce_b;
    wire mram_we;
    wire v5_prog_b;
    wire v5_cclk;
    wire v5_din;
    wire dbg_clk_3mhz;
    wire dbg_dbg_rst_n; 
    
    // Bidirectional
    wire [7:0] mram_dq;

    // Instantiate the Unit Under Test (UUT)
    v5_bootloader_top uut (
        .clk(clk), 
        .rst_n(rst_n), 
        .start_boot(start_boot),
        .mram_a(mram_a), 
        .mram_ce_b(mram_ce_b), 
        .mram_we(mram_we),
        .mram_dq(mram_dq),
        .v5_prog_b(v5_prog_b), 
        .v5_done(v5_done),
        .v5_cclk(v5_cclk), 
        .v5_din(v5_din),
        .dbg_clk_3mhz(dbg_clk_3mhz),
        .dbg_dbg_rst_n(dbg_dbg_rst_n)
    );
    // 12 MHz MASTER CLOCK (Period ~83.33 ns)
    always #41.67 clk = ~clk; 
    // MOCK MRAM 
    assign mram_dq = (mram_ce_b == 4'b1110 && mram_a == 21'h000000) ? 8'hA1 :
                     (mram_ce_b == 4'b1110 && mram_a == 21'h000001) ? 8'hB2 :
                     (mram_ce_b == 4'b1110 && mram_a == 21'h000002) ? 8'hC3 :
                     (mram_ce_b == 4'b0111 && mram_a == 21'h7FFFFF) ? 8'h99 : 8'hZZ;
    initial begin
        $display("\n=======================================================");
        $display("   TESTBENCH: ENVELOPE SIGNAL VERIFICATION ");
        $display("=======================================================\n");

        // Initial State
        clk = 0; 
        rst_n = 0; 
        start_boot = 0;
        v5_done = 0; 
        
        #200; 
        rst_n = 1; 
        
        // 1. Check initial state
        wait(v5_prog_b == 1'b0); 
        $display("[TIME: %0t] POWER UP: v5_prog_b pulled low.", $time);
        $display("[TIME: %0t] ENVELOPE CHECK: dbg_rst_n is %b (Should be 0)", $time, dbg_rst_n);
        
        #2000; 
        
        // 2. Press the button
        $display("\n[TIME: %0t] Lab engineer pressing start_boot...", $time);
        start_boot = 1; 
        #100;
        start_boot = 0;


        // 3. Verify envelope opens
        wait(dbg_rst_n == 1'b1); 
        $display("[TIME: %0t] ENVELOPE OPENED: dbg_rst_n spiked HIGH! Pipeline is active.", $time);
        
        // Let the pipeline run and shift out data
        #50000; 
        
        // 4. Virtex-5 finishes and raises v5_done
        $display("\n[TIME: %0t] Target Virtex-5 asserting v5_done...", $time);
        v5_done = 1;
        
        // 5. Verify envelope closes
        wait(dbg_rst_n == 1'b0); 
        $display("[TIME: %0t] ENVELOPE CLOSED: dbg_rst_n dropped LOW! Mission complete.", $time);

        #500;
        $display("\n=======================================================");
        $display("   TESTBENCH COMPLETE ");
        $display("=======================================================\n");
        $finish;
    end
endmodule

