`timescale 1ns/1ps

module async_fifo_coverage #(
    parameter int PTR_WIDTH = 4
)(
    // Write-side signals
    input logic                 wr_clk,
    input logic                 wr_rst_n,
    input logic                 wr_en,
    input logic                 full,
    input logic [PTR_WIDTH-1:0] wr_bin,

    // Read-side signals
    input logic                 rd_clk,
    input logic                 rd_rst_n,
    input logic                 rd_en,
    input logic                 empty,
    input logic [PTR_WIDTH-1:0] rd_bin
);

    // ==================================================
    // WRITE-SIDE FUNCTIONAL COVERAGE
    // ==================================================

    covergroup wr_cg @(posedge wr_clk);

        // ----------------------------------------------
        // Coverpoint 1:
        // Did FIFO reach both full and not-full states?
        // ----------------------------------------------
        cp_full : coverpoint full iff (wr_rst_n) {
            bins not_full = {0};
            bins full_hit = {1};
        }


        // ----------------------------------------------
        // Coverpoint 2:
        // Did we perform a legal/accepted write?
        //
        // Accepted write:
        // wr_en = 1 AND full = 0
        // ----------------------------------------------
        cp_write_accept :
            coverpoint (wr_en && !full) iff (wr_rst_n) {
                bins no  = {0};
                bins yes = {1};
            }


        // ----------------------------------------------
        // Coverpoint 3:
        // Did we attempt a write while FIFO was full?
        //
        // Blocked write:
        // wr_en = 1 AND full = 1
        // ----------------------------------------------
        cp_write_blocked :
            coverpoint (wr_en && full) iff (wr_rst_n) {
                bins no  = {0};
                bins yes = {1};
            }


        // ----------------------------------------------
        // Coverpoint 4:
        // Explicitly track wr_en itself
        // ----------------------------------------------
        cp_wr_en : coverpoint wr_en iff (wr_rst_n) {
            bins disabled = {0};
            bins enabled  = {1};
        }


        // ----------------------------------------------
        // Coverpoint 5:
        // Explicitly track full itself
        // ----------------------------------------------
        cp_full_state : coverpoint full iff (wr_rst_n) {
            bins not_full = {0};
            bins full     = {1};
        }


        // ----------------------------------------------
        // Cross coverage:
        // Did we see all combinations of wr_en and full?
        //
        // wr_en=0 full=0
        // wr_en=0 full=1
        // wr_en=1 full=0
        // wr_en=1 full=1
        // ----------------------------------------------
        cp_wr_en_full_cross :
            cross cp_wr_en, cp_full_state;


        // ----------------------------------------------
        // Coverpoint 6:
        // Did the write pointer wrap?
        //
        // For DEPTH = 8:
        // 0111 = address 7, wrap bit 0
        // 1000 = address 0, wrap bit 1
        // ----------------------------------------------
        cp_wr_wrap :
            coverpoint wr_bin iff (wr_rst_n) {
                bins wrap = (4'b0111 => 4'b1000);
            }

    endgroup


    // ==================================================
    // READ-SIDE FUNCTIONAL COVERAGE
    // ==================================================

    covergroup rd_cg @(posedge rd_clk);

        // ----------------------------------------------
        // Coverpoint 1:
        // Did FIFO reach both empty and not-empty states?
        // ----------------------------------------------
        cp_empty : coverpoint empty iff (rd_rst_n) {
            bins not_empty = {0};
            bins empty_hit = {1};
        }


        // ----------------------------------------------
        // Coverpoint 2:
        // Did we perform a legal/accepted read?
        //
        // Accepted read:
        // rd_en = 1 AND empty = 0
        // ----------------------------------------------
        cp_read_accept :
            coverpoint (rd_en && !empty) iff (rd_rst_n) {
                bins no  = {0};
                bins yes = {1};
            }


        // ----------------------------------------------
        // Coverpoint 3:
        // Did we attempt a read while FIFO was empty?
        //
        // Blocked read:
        // rd_en = 1 AND empty = 1
        // ----------------------------------------------
        cp_read_blocked :
            coverpoint (rd_en && empty) iff (rd_rst_n) {
                bins no  = {0};
                bins yes = {1};
            }


        // ----------------------------------------------
        // Coverpoint 4:
        // Explicitly track rd_en itself
        // ----------------------------------------------
        cp_rd_en : coverpoint rd_en iff (rd_rst_n) {
            bins disabled = {0};
            bins enabled  = {1};
        }


        // ----------------------------------------------
        // Coverpoint 5:
        // Explicitly track empty itself
        // ----------------------------------------------
        cp_empty_state : coverpoint empty iff (rd_rst_n) {
            bins not_empty = {0};
            bins empty     = {1};
        }


        // ----------------------------------------------
        // Cross coverage:
        // Did we see all combinations of rd_en and empty?
        //
        // rd_en=0 empty=0
        // rd_en=0 empty=1
        // rd_en=1 empty=0
        // rd_en=1 empty=1
        // ----------------------------------------------
        cp_rd_en_empty_cross :
            cross cp_rd_en, cp_empty_state;


        // ----------------------------------------------
        // Coverpoint 6:
        // Did the read pointer wrap?
        //
        // For DEPTH = 8:
        // 0111 = address 7, wrap bit 0
        // 1000 = address 0, wrap bit 1
        // ----------------------------------------------
        cp_rd_wrap :
            coverpoint rd_bin iff (rd_rst_n) {
                bins wrap = (4'b0111 => 4'b1000);
            }

    endgroup


    // ==================================================
    // CREATE COVERAGE INSTANCES
    // ==================================================

    wr_cg wr_cov = new();
    rd_cg rd_cov = new();

endmodule
