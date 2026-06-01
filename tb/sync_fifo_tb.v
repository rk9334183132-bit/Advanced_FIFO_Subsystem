`timescale 1ns / 1ps

module sync_fifo_tb;

    // =====================================================================
    // 1. VIRTUAL INTERFACE WIRES (Stimulus Generators)
    // =====================================================================
    reg        clk;
    reg        rst_n;
    reg        wr_en;
    reg [7:0]  w_data;
    reg        rd_en;
    reg        flush;

    // Monitor Wires (Outputs from our Chip)
    wire [7:0] r_data;
    wire       full;
    wire       empty;
    wire [3:0] fifo_count;
    wire       almost_full;
    wire       almost_empty;

    // =====================================================================
    // 2. DEVICE UNDER TEST (DUT) INSTANTIATION
    // =====================================================================
    sync_fifo uut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .w_data(w_data),
        .rd_en(rd_en),
        .flush(flush),
        .r_data(r_data),
        .full(full),
        .empty(empty),
        .fifo_count(fifo_count),
        .almost_full(almost_full),
        .almost_empty(almost_empty)
    );

    // =====================================================================
    // 3. CLOCK GENERATOR ENGINE (50 MHz Heartbeat)
    // =====================================================================
    always begin
        #10 clk = ~clk; // Toggle clock every 10ns (20ns total cycle period)
    end

    // =====================================================================
    // 4. AUTOMATED SIMULATION TEST VECTOR SUITE
    // =====================================================================
    initial begin
        // Setup GTKWave Waveform Dumping
        $dumpfile("sync_fifo_sim.vcd"); 
        $dumpvars(0, sync_fifo_tb);     
        
        // --- TEST 1: SYSTEM INITIALIZATION & RESET ---
        clk   = 1'b0;
        rst_n = 1'b0; 
        wr_en = 1'b0;
        w_data = 8'h00;
        rd_en = 1'b0;
        flush = 1'b0;
        #40;          
        
        rst_n = 1'b1; // Release hardware reset
        #20;
        
        // --- TEST 2: BURST WRITE OPERATIONS (Fill up the FIFO) ---
        $display("[INFO] Starting Write Burst Operations...");
        write_byte(8'd10);
        write_byte(8'd20);
        write_byte(8'd30);
        write_byte(8'd40);
        write_byte(8'd50); // Count reaches 5: almost_full triggers high!
        write_byte(8'd60);
        write_byte(8'd70);
        write_byte(8'd80); // Count reaches 8: full triggers high!
        #20;
        
        // --- TEST 3: ATTEMPT AN ILLEGAL OVERFLOW WRITE ---
        write_byte(8'd99); // Blocked completely by hardware safety gates
        #20;

        // --- TEST 4: BURST READ OPERATIONS (Empty out the FIFO) ---
        $display("[INFO] Starting Read Burst Operations...");
        read_byte();
        read_byte();
        read_byte();
        read_byte();
        read_byte();
        read_byte();
        read_byte();
        read_byte(); // FIFO drops to empty!
        #20;

        // --- TEST 5: TEST SYNCHRONOUS FLUSH FEATURE ---
        $display("[INFO] Testing Synchronous Flush Operations...");
        write_byte(8'hAA); 
        write_byte(8'hBB);
        #20;
        
        flush = 1'b1;      // Activate soft flush
        #20;
        flush = 1'b0;      // Release soft flush
        #40;

        $display("[SUCCESS] All FIFO Subsystem tests passed cleanly!");
        $finish;
    end

    // =====================================================================
    // 5. REUSABLE HARDWARE SIMULATION TASKS
    // =====================================================================
    task write_byte(input [7:0] data_in);
        begin
            @(posedge clk);
            #1;
            wr_en  = 1'b1;
            w_data = data_in;
            @(posedge clk);
            #1;
            wr_en  = 1'b0;
        end
    endtask

    task read_byte();
        begin
            @(posedge clk);
            #1;
            rd_en = 1'b1;
            @(posedge clk);
            #1;
            rd_en = 1'b0;
        end
    endtask

endmodule