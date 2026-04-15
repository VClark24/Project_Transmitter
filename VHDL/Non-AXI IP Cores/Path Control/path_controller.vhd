--------------------------------------------------------------------------------------------------------------------------
-- VHDL Compatibility: IEEE Std 1076-2008
-- Organisation: Southampton Solent University
-- Engineer: Vivienne Clark
-- Module Name: Path Selector
-- Revisions:
--  V1.0: Created 16/03/2026 in GitHub (https://github.com/VClark24/Project_Transmitter)
-- Comments:
--   This is the main Path Control block and the only one that is clocked (apart from the AXI transmit controller).
--   It has two main functions:
--     To take the waveform_sel signal from the Transmit Controller block and convert it to a path selection
--          waveform_sel = 10 or 11 (beacon or FHSS) => path_sel = 00 (bypasses framing and encoding blocks)
--          waveform_sel = 00 (telecommand) => path_sel = 01 (directs data to telecommand framing and encoding)
--          waveform_sel = 01 (telemetry) => path_sel = 10 (directs data to telemetry framing and encoding)
--     To determine when the waveform has been switched so that a request to temprorarily mute the transmit can be sent
-----------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity path_controller is
    port ( 
        clk : in std_logic;
        rst_n : in std_logic;
        waveform_sel_i : in std_logic_vector(1 downto 0);

        path_sel_o : out std_logic_vector(1 downto 0); -- 00=bypass, 01=TC, 10=TM, 11=reserved
        mute_req_o : out std_logic
    );
end path_controller;

architecture rtl of path_controller is
    type state_t is (RUN, SWITCH_RESET, SWITCH_WAIT);    -- 3-state FSM
    signal state : state_t := RUN;
    signal active_waveform_r : std_logic_vector(1 downto 0) := "10";
    signal wait_count_r : unsigned(4 downto 0) := (others => '0');
    signal path_sel_r : std_logic_vector(1 downto 0) := "00";
    signal mute_req_r : std_logic := '1';
begin
    path_sel_o <= path_sel_r;
    mute_req_o <= mute_req_r;

    process(active_waveform_r)
    begin
        path_sel_r <= "00"; -- default bypass

        case active_waveform_r is
            when "00" => -- Telecommand
                path_sel_r <= "01";
            when "01" => -- Telemetry
                path_sel_r <= "10";
            when "10" => -- Beacon
                path_sel_r <= "00";
            when "11" => -- FHSS
                path_sel_r <= "00";
            when others =>
                path_sel_r <= "00";
        end case;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                state <= RUN;
                active_waveform_r <= "10"; -- Beacon default
                wait_count_r <= (others => '0');
                mute_req_r <= '1';
            else
                case state is
                    when RUN =>                                        -- Default state
                        if waveform_sel_i /= active_waveform_r then    -- If waveform switch occurs ...
                            mute_req_r <= '1'; -- Mute transmitter
                            state <= SWITCH_RESET;
                        else
                            mute_req_r <= '0';                         -- If waveform switch not occurring ...
                            state <= RUN;                              -- Keep going
                        end if;

                    when SWITCH_RESET =>
                        mute_req_r <= '1';
                        active_waveform_r <= waveform_sel_i;                     -- Store new waveform as current waveform
                        wait_count_r <= to_unsigned(16, wait_count_r'length);    -- Wait a period 
                        state <= SWITCH_WAIT;

                    when SWITCH_WAIT =>
                        mute_req_r <= '1';
                        if wait_count_r = 0 then
                            wait_count_r <= (others => '0');
                            state <= RUN;  -- Once wait period has elapsed, run transmitter as normal.
                        else
                            wait_count_r <= wait_count_r - 1; -- If wait period has not elapsed, keep waiting
                            state <= SWITCH_WAIT;
                        end if;
                end case;
            end if;
        end if;
    end process;
end rtl;
