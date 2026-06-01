// =========================================================================
// Module Name:    sync_fifo
// Description:    Unified Core Synchronous FIFO Subsystem
//                 Includes: Core Array, MSB Pointer Math, Safety Fences,
//                           Real-Time Occupancy, Watermarks, and Soft Flush.
// =========================================================================

module sync_fifo (
    // Global Control Interface
    input  wire        clk,        // Core system clock (The heartbeat pulse)
    input  wire        rst_n,      // Hardware reset (0 = Reset System, 1 = Run)
    
    // Write Port (Input Channel)
    input  wire        wr_en,      // Write Enable (Set to 1 to push data in)
    input  wire [7:0]  w_data,     // 8-bit inbound data bus
    
    // Read Port (Output Channel)
    input  wire        rd_en,      // Read Enable (Set to 1 to pull data out)
    input  wire        flush,      // Synchronous Flush (1 = Instantly clear memory tracking)
    output wire [7:0]  r_data,     // 8-bit outbound data bus
    
    // Hardware Status Flags
    output wire        full,       // Status Flag: 1 means storage is 100% full
    output wire        empty,      // Status Flag: 1 means storage is 100% empty
    
    // Phase 2 Professional Ports
    output reg [3:0]   fifo_count, // Tracks the exact number of active entries (0 to 8)
    output reg         almost_full, // Early warning: FIFO is nearly full
    output reg         almost_empty // Early warning: FIFO is nearly empty
);

    // Baseline Fixed Configurations
    localparam FIFO_DEPTH = 8;     // The storage matrix has exactly 8 slots
    localparam ADDR_WIDTH = 3;     // 3 bits needed to index addresses 0 to 7 (2^3 = 8)

    // =====================================================================
    // INTERNAL STORAGE MATRIX & POINTER DECLARATIONS
    // =====================================================================
    reg [7:0] fifo_ram [0:FIFO_DEPTH-1]; // 8x8 RAM Matrix

    reg [ADDR_WIDTH:0] w_ptr; // 4-bit Write Pointer
    reg [ADDR_WIDTH:0] r_ptr; // 4-bit Read Pointer

    // =====================================================================
    // HARDWARE SAFETY PROTECTION GATES
    // =====================================================================
    wire write_allow;
    wire read_allow;

    assign write_allow = wr_en && !full && !flush;
    assign read_allow  = rd_en && !empty;

    // =====================================================================
    // MEMORY MATRIX WRITE & READ OPERATIONS
    // =====================================================================
    always @(posedge clk) begin
        if (write_allow) begin
            fifo_ram[w_ptr[ADDR_WIDTH-1:0]] <= w_data;
        end
    end

    assign r_data = fifo_ram[r_ptr[ADDR_WIDTH-1:0]];

    // =====================================================================
    // POINTER MANAGEMENT & TRACKING ENGINE (WITH FLUSH)
    // =====================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_ptr <= 4'b0000;
            r_ptr <= 4'b0000;
        end else if (flush) begin
            w_ptr <= 4'b0000;
            r_ptr <= 4'b0000;
        end else begin
            if (write_allow) begin
                w_ptr <= w_ptr + 1'b1;
            end
            if (read_allow) begin
                r_ptr <= r_ptr + 1'b1;
            end
        end
    end

    // =====================================================================
    // BOUNDARY FLAG STATUS GENERATION
    // =====================================================================
    assign empty = (w_ptr == r_ptr);
    
    assign full  = (w_ptr[ADDR_WIDTH] != r_ptr[ADDR_WIDTH]) && 
                   (w_ptr[ADDR_WIDTH-1:0] == r_ptr[ADDR_WIDTH-1:0]);

    // =====================================================================
    // REAL-TIME OCCUPANCY COUNTER LOGIC (WITH FLUSH)
    // =====================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_count <= 4'b0000;
        end else if (flush) begin
            fifo_count <= 4'b0000;
        end else begin
            case ({write_allow, read_allow})
                2'b10: fifo_count <= fifo_count + 1'b1;
                2'b01: fifo_count <= fifo_count - 1'b1;
                default: fifo_count <= fifo_count; // Handles 2'b00 and 2'b11 cleanly
            endcase
        end
    end

    // =====================================================================
    // WATERMARK INDICATOR LOGIC (WITH FLUSH)
    // =====================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            almost_full  <= 1'b0;
            almost_empty <= 1'b1;
        end else if (flush) begin
            almost_full  <= 1'b0;
            almost_empty <= 1'b1;
        end else begin
            almost_full  <= (fifo_count >= 4'd6);
            almost_empty <= (fifo_count <= 4'd2);
        end
    end

endmodule