`timescale 1ns/1ps

module tb_async_fifo;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 8;
    localparam int ADDR_WIDTH = $clog2(DEPTH);
    localparam int PTR_WIDTH  = ADDR_WIDTH + 1;

    // ==================================================
    // TESTBENCH SIGNALS
    // ==================================================

    logic                  wr_clk;
    logic                  wr_rst_n;
    logic                  wr_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic                  full;

    logic                  rd_clk;
    logic                  rd_rst_n;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] rd_data;
    logic                  empty;


    // ==================================================
    // SCOREBOARD / COUNTERS
    // ==================================================

    logic [DATA_WIDTH-1:0] expected_queue[$];

    int pass_count;
    int error_count;

    int random_write_count;
    int random_read_count;

    // ==================================================
    // DUT INSTANTIATION
    // ==================================================

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .wr_clk   (wr_clk),
        .wr_rst_n (wr_rst_n),
        .wr_en    (wr_en),
        .wr_data  (wr_data),
        .full     (full),

        .rd_clk   (rd_clk),
        .rd_rst_n (rd_rst_n),
        .rd_en    (rd_en),
        .rd_data  (rd_data),
        .empty    (empty)
    );
    
    
    // ==================================================
    // SVA CHECKER INSTANTIATION
    // ==================================================
    
    async_fifo_sva #(
    .PTR_WIDTH(PTR_WIDTH)
     ) sva_checker (
    .wr_clk         (wr_clk),
    .wr_rst_n       (wr_rst_n),
    .wr_en          (wr_en),
    .full            (full),
    .wr_bin          (dut.wr_bin),
    .wr_gray         (dut.wr_gray),

    .rd_clk          (rd_clk),
    .rd_rst_n        (rd_rst_n),
    .rd_en           (rd_en),
    .empty           (empty),
    .rd_bin          (dut.rd_bin),
    .rd_gray         (dut.rd_gray),

    .wr_gray_sync1   (dut.wr_gray_sync1),
    .wr_gray_sync2   (dut.wr_gray_sync2),
    .rd_gray_sync1   (dut.rd_gray_sync1),
    .rd_gray_sync2   (dut.rd_gray_sync2)
    );
    
    
    // ==================================================
    // COVERAGE CHECKER INSTANTIATION
    // ==================================================
    
    async_fifo_coverage #(
    .PTR_WIDTH(PTR_WIDTH)
    ) coverage_checker (
    .wr_clk   (wr_clk),
    .wr_rst_n (wr_rst_n),
    .wr_en    (wr_en),
    .full     (full),
    .wr_bin   (dut.wr_bin),

    .rd_clk   (rd_clk),
    .rd_rst_n (rd_rst_n),
    .rd_en    (rd_en),
    .empty    (empty),
    .rd_bin   (dut.rd_bin)
    );


    // ==================================================
    // WRITE CLOCK
    // 10 ns period = 100 MHz
    // ==================================================

    parameter int WR_HALF_PERIOD = 5;
    parameter int RD_HALF_PERIOD = 7;

    initial begin
      wr_clk = 0;
      forever #(WR_HALF_PERIOD) wr_clk = ~wr_clk;
      end

    initial begin
      rd_clk = 0;
      forever #(RD_HALF_PERIOD) rd_clk = ~rd_clk;
      end


    // ==================================================
    // RESET / INITIALIZATION
    // ==================================================

    initial begin
        wr_rst_n = 1'b0;
        rd_rst_n = 1'b0;

        wr_en   = 1'b0;
        rd_en   = 1'b0;
        wr_data = '0;

        pass_count         = 0;
        error_count        = 0;
        random_write_count = 0;
        random_read_count  = 0;

        expected_queue.delete();

        #20;

        wr_rst_n = 1'b1;
        rd_rst_n = 1'b1;
    end


    // ==================================================
    // NORMAL WRITE TASK
    // ==================================================

    task automatic write_byte(
        input logic [DATA_WIDTH-1:0] data
    );
        begin

            @(negedge wr_clk);

            while (full)
                @(negedge wr_clk);

            wr_en   = 1'b1;
            wr_data = data;

            @(posedge wr_clk);

            expected_queue.push_back(data);

            @(negedge wr_clk);

            wr_en   = 1'b0;
            wr_data = '0;

        end
    endtask


    // ==================================================
    // NORMAL READ + SCOREBOARD TASK
    // ==================================================

    task automatic read_byte;

        logic [DATA_WIDTH-1:0] expected;

        begin

            @(negedge rd_clk);

            while (empty)
                @(negedge rd_clk);

            rd_en = 1'b1;

            @(posedge rd_clk);

            if (expected_queue.size() == 0) begin

                $error(
                    "SCOREBOARD ERROR: expected queue empty during DUT read"
                );

                error_count++;

            end
            else begin

                expected = expected_queue.pop_front();

                #1;

                if (rd_data !== expected) begin

                    $error(
                        "DATA MISMATCH: expected=0x%0h actual=0x%0h",
                        expected,
                        rd_data
                    );

                    error_count++;

                end
                else begin

                    $display(
                        "PASS: expected=0x%0h actual=0x%0h",
                        expected,
                        rd_data
                    );

                    pass_count++;

                end
            end

            @(negedge rd_clk);

            rd_en = 1'b0;

        end
    endtask


    // ==================================================
    // WRITE-WHILE-FULL TEST TASK
    // ==================================================

    task automatic attempt_write_when_full(
        input logic [DATA_WIDTH-1:0] data
    );

        logic [$clog2(DEPTH):0] old_wr_bin;

        begin

            old_wr_bin = dut.wr_bin;

            @(negedge wr_clk);

            wr_en   = 1'b1;
            wr_data = data;

            @(posedge wr_clk);

            #1;

            if (dut.wr_bin !== old_wr_bin) begin

                $error(
                    "WRITE POINTER MOVED WHILE FIFO FULL"
                );

                error_count++;

            end
            else begin

                $display(
                    "PASS: write blocked while FIFO full"
                );

                pass_count++;

            end

            @(negedge wr_clk);

            wr_en   = 1'b0;
            wr_data = '0;

        end
    endtask


    // ==================================================
    // READ-WHILE-EMPTY TEST TASK
    // ==================================================

    task automatic attempt_read_when_empty;

        logic [$clog2(DEPTH):0] old_rd_bin;

        begin

            old_rd_bin = dut.rd_bin;

            @(negedge rd_clk);

            rd_en = 1'b1;

            @(posedge rd_clk);

            #1;

            if (dut.rd_bin !== old_rd_bin) begin

                $error(
                    "READ POINTER MOVED WHILE FIFO EMPTY"
                );

                error_count++;

            end
            else begin

                $display(
                    "PASS: read blocked while FIFO empty"
                );

                pass_count++;

            end

            @(negedge rd_clk);

            rd_en = 1'b0;

        end
    endtask


    // ==================================================
    // RANDOM WRITER
    // ==================================================

    task automatic random_writer(
        input int num_cycles
    );

        int i;
        logic [DATA_WIDTH-1:0] random_data;

        begin

            for (i = 0; i < num_cycles; i++) begin

                @(negedge wr_clk);

                if ($urandom_range(0, 1)) begin

                    random_data =
                        $urandom_range(
                            0,
                            (1 << DATA_WIDTH) - 1
                        );

                    if (!full) begin

                        wr_en   = 1'b1;
                        wr_data = random_data;

                    end
                    else begin

                        wr_en   = 1'b0;
                        wr_data = '0;

                    end
                end
                else begin

                    wr_en   = 1'b0;
                    wr_data = '0;

                end


                @(posedge wr_clk);

                if (wr_en && !full) begin

                    expected_queue.push_back(wr_data);

                    random_write_count++;

                end


                @(negedge wr_clk);

                wr_en   = 1'b0;
                wr_data = '0;

            end

        end

    endtask


    // ==================================================
    // RANDOM READER
    // ==================================================

    task automatic random_reader(
        input int num_cycles
    );

        int i;

        logic [DATA_WIDTH-1:0] expected;

        begin

            for (i = 0; i < num_cycles; i++) begin

                @(negedge rd_clk);

                if ($urandom_range(0, 1)) begin

                    if (!empty)
                        rd_en = 1'b1;
                    else
                        rd_en = 1'b0;

                end
                else begin

                    rd_en = 1'b0;

                end


                @(posedge rd_clk);

                if (rd_en && !empty) begin

                    if (expected_queue.size() == 0) begin

                        $error(
                            "RANDOM READ ERROR: scoreboard queue empty"
                        );

                        error_count++;

                    end
                    else begin

                        expected =
                            expected_queue.pop_front();

                        #1;

                        if (rd_data !== expected) begin

                            $error(
                                "RANDOM DATA MISMATCH: expected=0x%0h actual=0x%0h",
                                expected,
                                rd_data
                            );

                            error_count++;

                        end
                        else begin

                            pass_count++;
                            random_read_count++;

                        end

                    end

                end


                @(negedge rd_clk);

                rd_en = 1'b0;

            end

        end

    endtask


    // ==================================================
    // MAIN TEST SEQUENCE
    // ==================================================

    initial begin

        wait (wr_rst_n && rd_rst_n);

        #10;


        // ==================================================
        // TEST 1: BASIC FIFO ORDER
        // ==================================================

        $display("\n========================================");
        $display("TEST 1: BASIC FIFO ORDER");
        $display("========================================");

        write_byte(8'hA5);
        write_byte(8'h3C);
        write_byte(8'h7E);

        read_byte;
        read_byte;
        read_byte;

        wait (empty == 1'b1);

        if (expected_queue.size() == 0) begin

            $display(
                "PASS: scoreboard empty after basic test"
            );

            pass_count++;

        end
        else begin

            $error(
                "Scoreboard not empty after basic test"
            );

            error_count++;

        end


        // ==================================================
        // TEST 2: FILL FIFO TO FULL
        // ==================================================

        $display("\n========================================");
        $display("TEST 2: FILL FIFO TO FULL");
        $display("========================================");

        write_byte(8'h10);
        write_byte(8'h11);
        write_byte(8'h12);
        write_byte(8'h13);
        write_byte(8'h14);
        write_byte(8'h15);
        write_byte(8'h16);
        write_byte(8'h17);

        wait (full == 1'b1);

        if (full === 1'b1) begin

            $display(
                "PASS: full asserted after %0d writes",
                DEPTH
            );

            pass_count++;

        end
        else begin

            $error(
                "FULL did not assert"
            );

            error_count++;

        end


        // ==================================================
        // TEST 3: WRITE WHILE FULL
        // ==================================================

        $display("\n========================================");
        $display("TEST 3: WRITE WHILE FULL");
        $display("========================================");

        attempt_write_when_full(8'hFF);


        // ==================================================
        // TEST 4: DRAIN FIFO TO EMPTY
        // ==================================================

        $display("\n========================================");
        $display("TEST 4: DRAIN FIFO TO EMPTY");
        $display("========================================");

        repeat (DEPTH)
            read_byte;

        wait (empty == 1'b1);

        if (empty === 1'b1) begin

            $display(
                "PASS: empty asserted after FIFO drained"
            );

            pass_count++;

        end
        else begin

            $error(
                "EMPTY did not assert"
            );

            error_count++;

        end


        // ==================================================
        // TEST 5: READ WHILE EMPTY
        // ==================================================

        $display("\n========================================");
        $display("TEST 5: READ WHILE EMPTY");
        $display("========================================");

        attempt_read_when_empty;


        // ==================================================
        // TEST 6: POINTER WRAPAROUND + ORDERING
        // ==================================================

        $display("\n========================================");
        $display("TEST 6: POINTER WRAPAROUND + ORDERING");
        $display("========================================");

        // Write six entries
        write_byte(8'h20);
        write_byte(8'h21);
        write_byte(8'h22);
        write_byte(8'h23);
        write_byte(8'h24);
        write_byte(8'h25);

        // Read four entries
        repeat (4)
            read_byte;

        // Write another six
        // Forces write pointer to wrap
        write_byte(8'h30);
        write_byte(8'h31);
        write_byte(8'h32);
        write_byte(8'h33);
        write_byte(8'h34);
        write_byte(8'h35);

        // Read remaining eight entries
        repeat (8)
            read_byte;

        wait (empty == 1'b1);

        if (expected_queue.size() == 0) begin

            $display(
                "PASS: wraparound preserved FIFO ordering"
            );

            pass_count++;

        end
        else begin

            $error(
                "Wraparound test ended with %0d expected entries",
                expected_queue.size()
            );

            error_count++;

        end


        // ==================================================
        // TEST 7: RANDOMIZED CONCURRENT TRAFFIC
        // ==================================================

        $display("\n========================================");
        $display("TEST 7: RANDOMIZED CONCURRENT TRAFFIC");
        $display("========================================");

        random_write_count = 0;
        random_read_count  = 0;

        fork

            random_writer(200);

            random_reader(200);

        join


        // ==================================================
        // DRAIN ANY REMAINING RANDOM TRAFFIC
        // ==================================================

        while (expected_queue.size() > 0)
            read_byte;

        wait (empty == 1'b1);


        if (expected_queue.size() == 0) begin

            $display(
                "PASS: randomized traffic preserved FIFO ordering"
            );

            pass_count++;

        end
        else begin

            $error(
                "Random test ended with %0d scoreboard entries",
                expected_queue.size()
            );

            error_count++;

        end


        $display(
            "Random writes accepted = %0d",
            random_write_count
        );

        $display(
            "Random reads checked   = %0d",
            random_read_count
        );


        // ==================================================
        // FINAL RESULTS
        // ==================================================

        #20;

        $display("\n========================================");
        $display("VERIFICATION RESULTS");
        $display("========================================");

        $display(
            "PASS COUNT          = %0d",
            pass_count
        );

        $display(
            "ERROR COUNT         = %0d",
            error_count
        );

        $display(
            "RANDOM WRITES       = %0d",
            random_write_count
        );

        $display(
            "RANDOM READS        = %0d",
            random_read_count
        );


        if (error_count == 0)
            $display(
                "ALL DIRECTED + RANDOM TESTS PASSED"
            );
        else
            $display(
                "VERIFICATION FAILED"
            );

        $display("========================================\n");

        $finish;

    end

endmodule
