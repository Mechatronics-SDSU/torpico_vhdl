library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

library osvvm;
--use osvvm.AlertLogPkg.all; -- used for logging and assertions
context osvvm.OsvvmContext;

entity testCase_binary is
end entity;

architecture sim of testCase_binary is

    --------------------------------------------------------------------
    -- Constants
    --------------------------------------------------------------------
    -- DUT constants
    constant G_CLK_HZ       : integer := 50_000_000;
    constant G_BITWIDTH     : integer := 32;
    constant G_OUTPUT_HZ    : integer := 400;
    constant G_STOP_US      : integer := 1500;

    -- Testbench constants
    constant C_NUM_TESTS    : integer := 4; -- number of tests
    constant C_CLK_PRD_T    : time    := 20 ns; -- clock period tolerance
    constant C_TLRNCE_T     : time    := 2 * C_CLK_PRD_T + 1 ns;
    constant C_MAX_US       : integer := 1900;
    constant C_MIN_US       : integer := 1100;
    constant C_TESTNAME     : string  := "testCase_binary";
    constant C_BINARY_US    : integer := 1000; -- binary pulse width in us
    constant C_BINARY_T     : time    := C_BINARY_US * 1 us; -- binary pulse width in time
    constant C_NORMAL_US    : integer := 2000; -- normal pulse width in us
    constant C_NORMAL_T     : time    := C_NORMAL_US * 1 us; -- normal pulse width in time

    --------------------------------------------------------------------
    -- DUT signals
    --------------------------------------------------------------------
    signal tb_clk       : std_logic := '0';
    signal tb_rst_n     : std_logic := '0';
    signal tb_stop      : std_logic := '0';
    signal tb_pulse_us  : std_logic_vector(G_BITWIDTH-1 downto 0) := (others => '0');
    signal tb_pwm_sig   : std_logic;

    signal timeout      : time      := 3 ms;
    signal stim_done    : boolean   := false;
    signal resp_done    : boolean   := false;

    --------------------------------------------------------------------
    -- Procedures
    --------------------------------------------------------------------
    procedure set_pulse_us (
        signal tb_pulse_us : out std_logic_vector;
        constant us_int : in integer
    ) is
    begin
        tb_pulse_us <= std_logic_vector(to_unsigned(us_int, G_BITWIDTH));
    end procedure;

begin

    --------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------
    dut : entity work.pwm_gen
        generic map (
            G_CLK_HZ        => G_CLK_HZ,
            G_BITWIDTH      => G_BITWIDTH,
            G_OUTPUT_HZ     => G_OUTPUT_HZ,
            G_STOP_US       => G_STOP_US
        )
        port map (
            pl_clk      => tb_clk,
            rst_n       => tb_rst_n,
            stop_sig    => tb_stop,
            pulse_us    => tb_pulse_us,
            pwm_sig     => tb_pwm_sig
        );

    --------------------------------------------------------------------
    -- Clock
    --------------------------------------------------------------------
    clk_gen : process
    begin
        while true loop
            tb_clk <= '0';
            wait for C_CLK_PRD_T / 2;
            tb_clk <= '1';
            wait for C_CLK_PRD_T / 2;
        end loop;
    end process;

    --------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------
    stim_proc : process
        variable RV         : RandomPType;
        variable t_us       : integer   := 0;
        variable t_wait     : time      := 0 ns;
    begin
        SetLogEnable(INFO, TRUE);
        SetLogEnable(PASSED, TRUE);
        SetLogEnable(DEBUG, TRUE);

        Log(C_TESTNAME & ": Starting tb_pwm_gen", INFO);

        ----------------------------------------------------------------
        -- Initial state
        ----------------------------------------------------------------
        tb_rst_n <= '1';
        RV.InitSeed (RV'instance_name);

        for i in 0 to C_NUM_TESTS - 1 loop
            ----------------------------------------------------------------
            -- BINARY Test
            ----------------------------------------------------------------
            for j in 0 to RV.RandInt(1, 5) loop 
                t_us := 0;
                Log(C_TESTNAME & ": Set pulse_us=" & integer'image(t_us) & " us", INFO); -- log pulses
                set_pulse_us(tb_pulse_us, t_us); -- send pulse
                wait for C_BINARY_T;

                t_us := 1;
                Log(C_TESTNAME & ": Set pulse_us=" & integer'image(t_us) & " us", INFO); -- log pulses
                set_pulse_us(tb_pulse_us, t_us); -- send pulse
                wait for C_BINARY_T;
            end loop;

            ----------------------------------------------------------------
            -- NORMAL Test
            ----------------------------------------------------------------
            if i mod 2 = 0 then
                t_us := C_NORMAL_US;
                Log(C_TESTNAME & ": Set pulse_us=" & integer'image(t_us) & " us", INFO); -- log pulses
                set_pulse_us(tb_pulse_us, t_us); -- send pulse

            ----------------------------------------------------------------
            -- STOP Test
            ----------------------------------------------------------------
            else
                tb_stop <= '1'; -- send stop signal
            end if;
            wait for (10**6 / G_OUTPUT_HZ) * 4 us + C_CLK_PRD_T; -- wait for 1 output period

            -- send reset and clear signals
            tb_rst_n <= '0';
            set_pulse_us(tb_pulse_us, 0); -- clear pulse_us
            wait for 2 * C_CLK_PRD_T;
            tb_stop <= '0'; -- clear stop signal
            wait for 2 * C_CLK_PRD_T;
            tb_rst_n <= '1';

        end loop;
        wait for 1 us / G_CLK_HZ;

        ----------------------------------------------------------------
        -- Done
        ----------------------------------------------------------------
        stim_done <= true;
        Log( "stim_proc done", INFO);

        wait until resp_done = true;
        EndOfTestReports;
        stop;
        wait;
    end process;
    
    -------------------------------------------------------------------
    -- Response
    --------------------------------------------------------------------
    resp_proc : process
        variable t_expected : time := 0 ns; -- expected pulse width
        variable t_start    : time := 0 ns; -- start of pulse time stamp
        variable t_end      : time := 0 ns; -- end of pulse time stamp
        variable t_width    : time := 0 ns; -- width of pulse
        variable t_gap      : time := 0 ns; -- gap between pulses

        variable pass       : integer := 0; -- number of passes (correct duration)
        variable short      : integer := 0; -- high too short
        variable long       : integer := 0; -- high too long
        variable fail       : integer := 0; -- number of fails (incorrect duration or false neg)
        variable false_neg  : integer := 0; -- should be high while low

        variable pulse_us_was : integer     := 0; -- pulse_us at moment of signal going high
        variable stop_sig_was : std_logic   := '0'; -- stop_sig at moment of signal going high
    begin
        ----------------------------------------------------------------
        -- Response Loop
        ----------------------------------------------------------------
        resp_loop: while stim_done = false loop
            -- initialize loop
            wait until tb_pwm_sig = '1' or tb_rst_n = '0' for timeout; -- wait for output high
            t_start         := now; -- reset start time
            t_gap           := t_start - t_end; -- save gap time
            pulse_us_was    := to_integer(unsigned(tb_pulse_us)); -- capture pulse_us at moment of signal going high
            stop_sig_was    := tb_stop; -- capture stop_sig at moment of signal going high

            if tb_rst_n = '0' then
                next resp_loop; -- restart loop
            end if;

            wait until tb_pwm_sig = '0' or tb_rst_n = '0' for timeout; -- wait for output low
            t_end := now; -- reset start time
            t_width := t_end - t_start; -- calculate pulse width

            if tb_rst_n = '0' then
                next resp_loop; -- restart loop
            end if;
            
            if pulse_us_was = 0 and stop_sig_was = '0' then
                if t_gap < C_BINARY_T - 2 us or t_gap > C_BINARY_T + 2 us then
                    AffirmIf(TRUE,
                        C_TESTNAME & ": PASS - pwm_sig low for " &
                        integer'image(t_gap / 1 us) &
                        " when pulse_us was " &
                        integer'image(pulse_us_was) &
                        ", stop_sig was " & 
                        std_logic'image(stop_sig_was)
                    );
                    pass := pass + 1;
            else
                AffirmIf(FALSE,
                    C_TESTNAME & ": FAIL - pwm_sig low " &
                    integer'image(t_gap / 1 us) &
                    " when pulse_us was " &
                    integer'image(pulse_us_was) &
                    ", stop_sig was " & 
                    std_logic'image(stop_sig_was)
                );
                fail := fail + 1;
            end if;
            else
                if pulse_us_was = 1 and stop_sig_was = '0' then
                    t_expected := C_BINARY_T;

                elsif stop_sig_was = '1' then
                    t_expected := G_STOP_US * 1 us;
                else
                    t_expected := pulse_us_was * 1 us;
                end if;

                if t_width > t_expected - C_TLRNCE_T and t_width < t_expected + C_TLRNCE_T then
                    AffirmIf(TRUE,
                        C_TESTNAME & ": PASS - pwm_sig high for " &
                        integer'image(t_width / 1 us) &
                        " when pulse_us was " &
                        integer'image(pulse_us_was) &
                        ", stop_sig was " & 
                        std_logic'image(stop_sig_was)
                    );
                    pass := pass + 1;
                else
                    AffirmIf(FALSE,
                        C_TESTNAME & ": FAIL - pwm_sig high for " &
                        integer'image(t_width / 1 us) &
                        " when pulse_us was " &
                        integer'image(pulse_us_was) &
                        ", stop_sig was " & 
                        std_logic'image(stop_sig_was)
                    );
                    fail := fail + 1;
                end if;
            end if;

        end loop;

        ----------------------------------------------------------------
        -- Print Test Results
        ----------------------------------------------------------------
        wait for 1 ms;
        Log(C_TESTNAME & ": RESULTS - pass: " & integer'image(pass) &
        ", fail: " & integer'image(fail) &
        ", short: " & integer'image(short) &
        ", long: " & integer'image(long) &
        ", false neg: " & integer'image(false_neg));

        resp_done <= true;
        wait;
    end process;

end architecture;