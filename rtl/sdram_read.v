`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/06 19:27:54
// Module Name: sdram_read
// Description: SDRAM读逻辑, Full-Page读取
//////////////////////////////////////////////////////////////////////////////////


module sdram_read(
        input   wire            clk             ,
        input   wire            rst_n           ,
        input   wire    [23:0]  rd_addr         ,
        input   wire    [15:0]  rd_sdram_data   ,
        input   wire    [9:0]   rd_burst_len    ,
        input   wire            rd_en           ,
        
        output  reg             rd_ack          ,
        output  reg     [3:0]   rd_cmd          ,
        output  reg     [1:0]   rd_bank_addr    ,
        output  reg     [12:0]  rd_sdram_addr   ,
        output  wire            rd_end          ,
        output  wire    [15:0]  rd_data         
    );
    
    //状态机状态定义
    parameter   IDLE        =   9'b000_000_001,
                ACTIVE      =   9'b000_000_010,
                WAIT_TRCD   =   9'b000_000_100,
                READ        =   9'b000_001_000,
                WAIT_CAS    =   9'b000_010_000,
                BURST_READ  =   9'b000_100_000,
                PRE_CHARG   =   9'b001_000_000,
                WAIT_TRP    =   9'b010_000_000,
                RD_END      =   9'b100_000_000;
    
    //命令定义
    parameter   NOP_CMD         =   4'b1000,  //8
                ACTIVE_CMD      =   4'b0011,  //3
                READ_CMD        =   4'b0101,  //5
                BURST_TERM_CMD  =   4'b0110,  //6
                PRE_CHARG_CMD   =   4'b0010;  //2
                
    //时间周期定义
    parameter   TRCD            =   9'd2,
                TRP             =   9'd2,
                CAS             =   3'b011;  //CAS-latency

    //输入地址解析
    wire [1:0]    bank_addr   ; 
    wire [12:0]   row_addr    ;
    wire [8:0]    column_addr ;
    
    assign bank_addr    = rd_addr[23:22]        ;
    assign row_addr     = rd_addr[21:9]         ;
    assign column_addr  = {4'b0,rd_addr[8:0]}   ;

    //中间信号
    reg     [8:0]   state       ;
    reg     [8:0]   next_state  ;
    reg     [9:0]   cnt_clk     ; //定时计数器信号
    reg             cnt_clk_res ; //定时计数器复位信号,高电平有效
    wire            trcd_end    ; //Trcd时长等待完毕
    wire            trp_end     ; //Trp时长等待完毕    
    wire            burst_end   ; //突发传输完成flag   
    wire            cas_end     ; //CAS-latency等待完成flag
    reg             burst_term  ; //BURST_TERMINAL标志,高电平时表示需要发送BURST_TERMINAL命令,终止突发传输
    reg     [15:0]  rd_data_reg ; //输入数据寄存器,打拍实现SDRAM读取数据的同步
    
    //cnt_clk
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_clk <= 10'd0;
        end else if(cnt_clk_res) begin
            cnt_clk <= 10'd0;
        end else begin
            cnt_clk <= cnt_clk + 10'd1;
        end
    end
    
    //计时完成标志信号
    assign trcd_end = (state == WAIT_TRCD && cnt_clk == TRCD)?1'b1:1'b0;
    assign trp_end  = (state == WAIT_TRP && cnt_clk == TRP)?1'b1:1'b0;

    //突发传输完成flag
    assign burst_end = (state == BURST_READ && cnt_clk == (rd_burst_len + CAS - 1))?1'b1:1'b0;
    
    //cas_end
    //在READ状态下也可能出现cas_end信号,此时状态机不会再出现WAIT_CAS状态
    assign cas_end  = ((state == WAIT_CAS || state == READ) && cnt_clk == CAS - 1)?1'b1:1'b0;
    
    //burst_term
    always@(posedge clk or negedge rst_n) begin
        case(state)
            //burst_STOP信号可能出现在WAIT_CAS, BURST_READ状态下
            WAIT_CAS, BURST_READ: begin
                if(cnt_clk == rd_burst_len - 10'd1) begin
                    burst_term <= 1'b1;
                end else begin
                    burst_term <= 1'b0;
                end
            end
            default: begin
                burst_term <= 1'b0;
            end
        endcase
    end
    
    
    //cnt_clk_res
    always@(*) begin
        case(state) 
            IDLE, RD_END: begin
                cnt_clk_res = 1'b1;
            end
            WAIT_TRCD: begin
                cnt_clk_res = trcd_end;
            end
            WAIT_TRP: begin
                cnt_clk_res = trp_end;
            end
            BURST_READ: begin
                cnt_clk_res = burst_end;
            end
            default: begin
                cnt_clk_res = 1'b0;
            end
        endcase
    end
    
    
    
    //三段式状态机
    
    //状态机时序
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    //状态机次态
    //next_state
    always@(*) begin
        case(state)
            IDLE: begin
                if(rd_en) begin
                    next_state = ACTIVE;
                end else begin
                    next_state = IDLE;
                end
            end
            
            ACTIVE: begin
                next_state = WAIT_TRCD;
            end
            
            WAIT_TRCD: begin
                if(trcd_end) begin
                    next_state = READ;
                end else begin
                    next_state = WAIT_TRCD;
                end
            end
            
            READ: begin
                if(cas_end) begin
                    next_state = BURST_READ; //CAS-latency为1,很短,无需进入多余的WAIT_CAS
                end else begin
                    next_state = WAIT_CAS;  //CAS-latency大于1,需要进入WAIT_CAS状态
                end
            end
            
            WAIT_CAS: begin
                if(cas_end) begin
                    next_state = BURST_READ;
                end else begin
                    next_state = WAIT_CAS;
                end
            end
            
            BURST_READ: begin
                if(burst_end) begin
                    next_state = PRE_CHARG;
                end else begin
                    next_state = BURST_READ;
                end
            end
            
            PRE_CHARG: begin
                next_state = WAIT_TRP;
            end
            
            WAIT_TRP: begin
                if(trp_end) begin
                    next_state = RD_END;
                end else begin
                    next_state = WAIT_TRP;
                end
            end
            
            RD_END: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    //输出
    //rd_cmd
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_cmd <= NOP_CMD;
        end else case(state) 
            ACTIVE: begin   
                rd_cmd <= ACTIVE_CMD;
            end
            
            READ: begin
                rd_cmd <= READ_CMD;
            end
            
            PRE_CHARG: begin
                rd_cmd <= PRE_CHARG_CMD;
            end
            
            default: begin
                if(burst_term) begin
                    rd_cmd <= BURST_TERM_CMD; //到了停止突发传输的时刻
                end else begin
                    rd_cmd <= NOP_CMD;
                end
            end
            
        endcase
    end
    
    //rd_bank_addr
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_bank_addr <= 2'b11;
        end else case(state)
            ACTIVE, READ, PRE_CHARG: begin
                rd_bank_addr <= bank_addr; //高两位是bank地址
            end
            default: begin
                rd_bank_addr <= 2'b11;
            end
        endcase
    end    

    //rd_sdram_addr
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_sdram_addr <= 13'h1fff;
        end else case(state)
            ACTIVE: begin
                rd_sdram_addr <= row_addr; //激活地址总线行地址
            end
            PRE_CHARG: begin
                rd_sdram_addr <= 13'h1dff; //预充电时A[10]为低电平,则只预充电选中bank
            end
            READ: begin
                rd_sdram_addr <= column_addr; //读操作时是列首地址
            end
            default: begin
                rd_sdram_addr <= 13'h1fff;
            end
        endcase
    end  

    //rd_end
    assign rd_end = (state == RD_END)?1'b1:1'b0;
    
    //rd_data_reg
    //对输入数据打拍, 以对齐时钟
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_data_reg <= 16'b0;
        end else begin
            rd_data_reg <= rd_sdram_data;
        end
    end
    
    //rd_data
    assign rd_data = rd_data_reg & {16{rd_ack}};
    
    //rd_ack
    //对状态机state打拍得到rd_ack
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_ack      <= 1'b0;
        end else begin
            rd_ack   <= (state == BURST_READ)?1'b1:1'b0;
        end 
    end
    
    
endmodule
