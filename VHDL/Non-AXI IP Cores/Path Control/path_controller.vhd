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
    type state_t is (RUN, SWITCH_RESET, SWITCH_WAIT);
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
                    when RUN =>
                        if waveform_sel_i /= active_waveform_r then
                            mute_req_r <= '1';
                            state <= SWITCH_RESET;
                        else
                            mute_req_r <= '0';
                            state <= RUN;
                        end if;

                    when SWITCH_RESET =>
                        mute_req_r <= '1';
                        active_waveform_r <= waveform_sel_i;
                        wait_count_r <= to_unsigned(16, wait_count_r'length);
                        state <= SWITCH_WAIT;

                    when SWITCH_WAIT =>
                        mute_req_r <= '1';
                        if wait_count_r = 0 then
                            wait_count_r <= (others => '0');
                            state <= RUN;
                        else
                            wait_count_r <= wait_count_r - 1;
                            state <= SWITCH_WAIT;
                        end if;
                end case;
            end if;
        end if;
    end process;
end rtl;
