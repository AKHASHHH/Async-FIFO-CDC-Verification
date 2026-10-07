#!/bin/tcsh

setenv VCS_HOME /eda/synopsys/vcs/Y-2026.03
set path=($VCS_HOME/bin $path)

set SCRIPT_DIR = `dirname "$0"`
cd "$SCRIPT_DIR/.."
mkdir -p sim logs

vcs -full64 -sverilog rtl/async_fifo.sv assertions/async_fifo_sva.sv coverage/async_fifo_coverage.sv tb/tb_async_fifo.sv -top tb_async_fifo -o sim/simv

if ($status != 0) then
    echo "Compilation failed"
    exit 1
endif

set PASS_COUNT = 0
set FAIL_COUNT = 0

@ SEED = 1

while ($SEED <= 100)

    echo "========================================"
    echo "Running seed $SEED"
    echo "========================================"

    ./sim/simv +ntb_random_seed=$SEED > logs/regression_seed_${SEED}.log

    grep -q "ALL DIRECTED + RANDOM TESTS PASSED" logs/regression_seed_${SEED}.log

    if ($status == 0) then
        echo "SEED $SEED : PASS"
        @ PASS_COUNT++
    else
        echo "SEED $SEED : FAIL"
        @ FAIL_COUNT++
    endif

    @ SEED++

end

echo ""
echo "========================================"
echo "REGRESSION SUMMARY"
echo "========================================"
echo "PASS = $PASS_COUNT"
echo "FAIL = $FAIL_COUNT"
echo "========================================"
