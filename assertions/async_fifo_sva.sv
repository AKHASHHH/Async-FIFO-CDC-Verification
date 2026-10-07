`timescale 1ns/1ps

module async_fifo_sva #(
    parameter int PTR_WIDTH = 4
)(
    // Write-side signals
    input logic                 wr_clk,
    input logic                 wr_rst_n,
    input logic                 wr_en,
    input logic                 full,
    input logic [PTR_WIDTH-1:0] wr_bin,
    input logic [PTR_WIDTH-1:0] wr_gray,

    // Read-side signals
    input logic                 rd_clk,
    input logic                 rd_rst_n,
    input logic                 rd_en,
    input logic                 empty,
    input logic [PTR_WIDTH-1:0] rd_bin,
    input logic [PTR_WIDTH-1:0] rd_gray,

    // Synchronizer signals
    input logic [PTR_WIDTH-1:0] wr_gray_sync1,
    input logic [PTR_WIDTH-1:0] wr_gray_sync2,
    input logic [PTR_WIDTH-1:0] rd_gray_sync1,
    input logic [PTR_WIDTH-1:0] rd_gray_sync2
);

    // ==================================================
    // ASSERTION 1:
    // Write pointer must hold when FIFO is full
    // ==================================================

    property p_wr_hold_when_full;
        @(posedge wr_clk)
        disable iff (!wr_rst_n)
        (wr_en && full)
        |=> (wr_bin == $past(wr_bin));
    endproperty

    a_wr_hold_when_full:
        assert property (p_wr_hold_when_full)
        else
            $error("ASSERTION FAILED: wr_bin changed while FIFO was full");


    // ==================================================
    // ASSERTION 2:
    // Accepted write must increment write pointer by 1
    // ==================================================

    property p_wr_increment_on_accept;
        @(posedge wr_clk)
        disable iff (!wr_rst_n)
        (wr_en && !full)
        |=> (wr_bin == $past(wr_bin) + 1'b1);
    endproperty

    a_wr_increment_on_accept:
        assert property (p_wr_increment_on_accept)
        else
            $error("ASSERTION FAILED: wr_bin did not increment after accepted write");


    // ==================================================
    // ASSERTION 3:
    // Read pointer must hold when FIFO is empty
    // ==================================================

    property p_rd_hold_when_empty;
        @(posedge rd_clk)
        disable iff (!rd_rst_n)
        (rd_en && empty)
        |=> (rd_bin == $past(rd_bin));
    endproperty

    a_rd_hold_when_empty:
        assert property (p_rd_hold_when_empty)
        else
            $error("ASSERTION FAILED: rd_bin changed while FIFO was empty");


    // ==================================================
    // ASSERTION 4:
    // Accepted read must increment read pointer by 1
    // ==================================================

    property p_rd_increment_on_accept;
        @(posedge rd_clk)
        disable iff (!rd_rst_n)
        (rd_en && !empty)
        |=> (rd_bin == $past(rd_bin) + 1'b1);
    endproperty

    a_rd_increment_on_accept:
        assert property (p_rd_increment_on_accept)
        else
            $error("ASSERTION FAILED: rd_bin did not increment after accepted read");


    // ==================================================
    // ASSERTION 5:
    // Write Gray pointer changes by at most one bit
    // ==================================================

    property p_wr_gray_one_bit;
        @(posedge wr_clk)
        disable iff (!wr_rst_n)
        $onehot0(wr_gray ^ $past(wr_gray));
    endproperty

    a_wr_gray_one_bit:
        assert property (p_wr_gray_one_bit)
        else
            $error("ASSERTION FAILED: wr_gray changed by more than one bit");


    // ==================================================
    // ASSERTION 6:
    // Read Gray pointer changes by at most one bit
    // ==================================================

    property p_rd_gray_one_bit;
        @(posedge rd_clk)
        disable iff (!rd_rst_n)
        $onehot0(rd_gray ^ $past(rd_gray));
    endproperty

    a_rd_gray_one_bit:
        assert property (p_rd_gray_one_bit)
        else
            $error("ASSERTION FAILED: rd_gray changed by more than one bit");


    // ==================================================
    // ASSERTION 7:
    // Write Gray pointer must match binary-to-Gray encoding
    // ==================================================

    property p_wr_gray_encoding;
        @(posedge wr_clk)
        disable iff (!wr_rst_n)
        wr_gray == (wr_bin ^ (wr_bin >> 1));
    endproperty

    a_wr_gray_encoding:
        assert property (p_wr_gray_encoding)
        else
            $error("ASSERTION FAILED: wr_gray does not match wr_bin Gray encoding");


    // ==================================================
    // ASSERTION 8:
    // Read Gray pointer must match binary-to-Gray encoding
    // ==================================================

    property p_rd_gray_encoding;
        @(posedge rd_clk)
        disable iff (!rd_rst_n)
        rd_gray == (rd_bin ^ (rd_bin >> 1));
    endproperty

    a_rd_gray_encoding:
        assert property (p_rd_gray_encoding)
        else
            $error("ASSERTION FAILED: rd_gray does not match rd_bin Gray encoding");


    // ==================================================
    // ASSERTION 9:
    // Write-side reset state must be correct
    // ==================================================

    property p_wr_reset_state;
        @(posedge wr_clk)
        (!wr_rst_n)
        |-> (
            wr_bin  == '0 &&
            wr_gray == '0 &&
            full    == 1'b0
        );
    endproperty

    a_wr_reset_state:
        assert property (p_wr_reset_state)
        else
            $error("ASSERTION FAILED: write-side reset state is incorrect");


    // ==================================================
    // ASSERTION 10:
    // Read-side reset state must be correct
    // ==================================================

    property p_rd_reset_state;
        @(posedge rd_clk)
        (!rd_rst_n)
        |-> (
            rd_bin  == '0 &&
            rd_gray == '0 &&
            empty   == 1'b1
        );
    endproperty

    a_rd_reset_state:
        assert property (p_rd_reset_state)
        else
            $error("ASSERTION FAILED: read-side reset state is incorrect");


    // ==================================================
    // ASSERTION 11:
    // Write-pointer synchronizer must behave as a 2FF pipeline
    // ==================================================

    property p_wr_sync_pipeline;
        @(posedge rd_clk)
        disable iff (!rd_rst_n)
        wr_gray_sync2 == $past(wr_gray_sync1);
    endproperty

    a_wr_sync_pipeline:
        assert property (p_wr_sync_pipeline)
        else
            $error("ASSERTION FAILED: wr_gray_sync2 did not capture previous wr_gray_sync1");


    // ==================================================
    // ASSERTION 12:
    // Read-pointer synchronizer must behave as a 2FF pipeline
    // ==================================================

    property p_rd_sync_pipeline;
        @(posedge wr_clk)
        disable iff (!wr_rst_n)
        rd_gray_sync2 == $past(rd_gray_sync1);
    endproperty

    a_rd_sync_pipeline:
        assert property (p_rd_sync_pipeline)
        else
            $error("ASSERTION FAILED: rd_gray_sync2 did not capture previous rd_gray_sync1");

endmodule
