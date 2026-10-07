#!/bin/tcsh

setenv VCS_HOME /eda/synopsys/vcs/Y-2026.03
set path=($VCS_HOME/bin $path)

set SCRIPT_DIR = `dirname "$0"`
cd "$SCRIPT_DIR/.."
mkdir -p sim logs

set PASS_COUNT = 0
set FAIL_COUNT = 0

foreach CASE (baseline writer_fast reader_fast close_freq)

    if ("$CASE" == "baseline") then
        set WR_HALF = 5
        set RD_HALF = 7
    else if ("$CASE" == "writer_fast") then
        set WR_HALF = 3
        set RD_HALF = 7
    else if ("$CASE" == "reader_fast") then
        set WR_HALF = 7
        set RD_HALF = 3
    else if ("$CASE" == "close_freq") then
        set WR_HALF = 5
        set RD_HALF = 6
    endif

    echo "========================================"
    echo "CASE: $CASE"
    echo "WR_HALF_PERIOD = $WR_HALF"
    echo "RD_HALF_PERIOD = $RD_HALF"
    echo "========================================"

    vcs -full64 -sverilog \
        -pvalue+tb_async_fifo.WR_HALF_PERIOD=$WR_HALF \
        -pvalue+tb_async_fifo.RD_HALF_PERIOD=$RD_HALF \
        rtl/async_fifo.sv \
        assertions/async_fifo_sva.sv \
        coverage/async_fifo_coverage.sv \
        tb/tb_async_fifo.sv \
        -top tb_async_fifo \
        -o sim/simv_${CASE} > logs/compile_${CASE}.log

    if ($status != 0) then
        echo "$CASE : COMPILE FAIL"
        @ FAIL_COUNT++
        continue
    endif

    ./sim/simv_${CASE} +ntb_random_seed=42 > logs/clock_${CASE}.log

    grep -q "ALL DIRECTED + RANDOM TESTS PASSED" logs/clock_${CASE}.log

    if ($status == 0) then
        echo "$CASE : PASS"
        @ PASS_COUNT++
    else
        echo "$CASE : FAIL"
        @ FAIL_COUNT++
    endif

end

echo ""
echo "========================================"
echo "CLOCK RATIO REGRESSION SUMMARY"
echo "========================================"
echo "PASS = $PASS_COUNT"
echo "FAIL = $FAIL_COUNT"
echo "========================================"
