`timescale 1ns/1ps

module async_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 8
)(
    // Write domain
    input  logic                  wr_clk,
    input  logic                  wr_rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  full,

    // Read domain
    input  logic                  rd_clk,
    input  logic                  rd_rst_n,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  empty
);

    localparam int ADDR_WIDTH = $clog2(DEPTH);
    localparam int PTR_WIDTH  = ADDR_WIDTH + 1;

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic [PTR_WIDTH-1:0] wr_bin, wr_bin_next;
    logic [PTR_WIDTH-1:0] wr_gray, wr_gray_next;

    logic [PTR_WIDTH-1:0] rd_bin, rd_bin_next;
    logic [PTR_WIDTH-1:0] rd_gray, rd_gray_next;

    logic [PTR_WIDTH-1:0] wr_gray_sync1, wr_gray_sync2;
    logic [PTR_WIDTH-1:0] rd_gray_sync1, rd_gray_sync2;

    logic full_next;
    logic empty_next;

    always_comb begin
        wr_bin_next = wr_bin;

        if (wr_en && !full)
            wr_bin_next = wr_bin + 1'b1;

        wr_gray_next = wr_bin_next ^ (wr_bin_next >> 1);
    end

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_bin  <= '0;
            wr_gray <= '0;
        end
        else begin
            wr_bin  <= wr_bin_next;
            wr_gray <= wr_gray_next;
        end
    end

    always_ff @(posedge wr_clk) begin
        if (wr_en && !full)
            mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data;
    end

    always_comb begin
        rd_bin_next = rd_bin;

        if (rd_en && !empty)
            rd_bin_next = rd_bin + 1'b1;

        rd_gray_next = rd_bin_next ^ (rd_bin_next >> 1);
    end

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_bin  <= '0;
            rd_gray <= '0;
        end
        else begin
            rd_bin  <= rd_bin_next;
            rd_gray <= rd_gray_next;
        end
    end

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n)
            rd_data <= '0;
        else if (rd_en && !empty)
            rd_data <= mem[rd_bin[ADDR_WIDTH-1:0]];
    end

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_gray_sync1 <= '0;
            wr_gray_sync2 <= '0;
        end
        else begin
            wr_gray_sync1 <= wr_gray;
            wr_gray_sync2 <= wr_gray_sync1;
        end
    end

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_gray_sync1 <= '0;
            rd_gray_sync2 <= '0;
        end
        else begin
            rd_gray_sync1 <= rd_gray;
            rd_gray_sync2 <= rd_gray_sync1;
        end
    end

    always_comb begin
        empty_next = (rd_gray_next == wr_gray_sync2);
    end

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n)
            empty <= 1'b1;
        else
            empty <= empty_next;
    end

    always_comb begin
        full_next =
            (wr_gray_next ==
             {~rd_gray_sync2[PTR_WIDTH-1:PTR_WIDTH-2],
               rd_gray_sync2[PTR_WIDTH-3:0]});
    end

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n)
            full <= 1'b0;
        else
            full <= full_next;
    end

endmodule
