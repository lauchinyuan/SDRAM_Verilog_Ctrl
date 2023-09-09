`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email:lauchinyuan@yeah.net
// Create Date: 2023/09/05 22:44:31
// Module Name: sdram_write
// Description: SDRAM写逻辑, full-page突发传输模式
//////////////////////////////////////////////////////////////////////////////////


module sdram_write(
        input   wire        clk             ,
        input   wire        rst_n           ,
        input   wire        wr_en           ,
        input   wire [23:0] wr_addr         ,  //2bit Bank_addr + 13bit Row_addr + 9bit Column_addr
        input   wire [15:0] wr_data         ,
        input   wire [9:0]  wr_burst_len    ,
        
        output  reg  [3:0]  wr_cmd          ,
        output  reg  [1:0]  wr_bank_addr    ,
        output  reg  [12:0] wr_sdram_addr   ,
        output  wire [15:0] wr_sdram_data   ,
        output  wire        wr_end          ,
        output  wire        wr_ack          ,
        output  reg         wr_sdram_en     
    );
    
    //列单元数定义
    parameter   MAX_COLUMN  =   10'd512     ;
    
    //状态机状态定义
    parameter   IDLE        =   9'b000_000_001,
                ACTIVE      =   9'b000_000_010,
                WAIT_TRCD   =   9'b000_000_100,
                WRITE       =   9'b000_001_000,
                BURST_WRITE =   9'b000_010_000,
                BURST_TERM  =   9'b000_100_000,
                PRE_CHARG   =   9'b001_000_000,
                WAIT_TRP    =   9'b010_000_000,
                WR_END      =   9'b100_000_000;
                
    //命令定义
    parameter   NOP_CMD         =   4'b1000,
                ACTIVE_CMD      =   4'b0011,
                WRITE_CMD       =   4'b0100,
                BURST_TERM_CMD  =   4'b0110,
                PRE_CHARG_CMD   =   4'b0010;
                
    //时间周期定义
    parameter   TRCD            =   9'd2    ,
                TRP             =   9'd2    ;
    
                
                
    //输入地址解析
    wire [1:0]    bank_addr   ; 
    wire [12:0]   row_addr    ;
    wire [8:0]    column_addr ;
    
    assign bank_addr    = wr_addr[23:22]        ;
    assign row_addr     = wr_addr[21:9]         ;
    assign column_addr  = {4'b0,wr_addr[8:0]}   ;
    
    
    
                
    //中间信号
    reg     [8:0]   state           ;
    reg     [8:0]   next_state      ;
    reg     [8:0]   cnt_clk         ; //定时计数器信号
    reg             cnt_clk_res     ; //定时计数器复位信号,高电平有效
    wire            trcd_end        ; //Trcd时长等待完毕
    wire            trp_end         ; //Trp时长等待完毕    
    wire            burst_end       ; //突发传输完成flag
    
    //处理突发传输溢出(突发连续写入的地址空间跨越不同行, 则需要暂停当前行写入, 并在新行重新进行发起写操作)
    reg             wr_overflow     ; //当前写入的(column_addr + wr_burst_len) > MAX_COLUMN
    reg     [9:0]   burst_len       ; //实际写操作的有效突发长度,没有溢出时是wr_burst_len, 溢出时更短
    reg     [12:0]  column_addr_reg ; //寄存实际写入的列首地址
    
    

    
    
    //cnt_clk
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_clk <= 9'd0;
        end else if(cnt_clk_res) begin
            cnt_clk <= 9'd0;
        end else begin
            cnt_clk <= cnt_clk + 9'd1;
        end
    end
    
    //计时完成标志信号
    assign trcd_end = (state == WAIT_TRCD && cnt_clk == TRCD)?1'b1:1'b0;
    assign trp_end  = (state == WAIT_TRP && cnt_clk == TRP)?1'b1:1'b0;
    
    //突发传输完成flag, 可能在BURST_WRITE、WRITE两种状态下出现
    assign burst_end = ((state == BURST_WRITE || state == WRITE) && cnt_clk == (burst_len - 1))?1'b1:1'b0;
    
    //cnt_clk_res
    always@(*) begin    
        case(state) 
            IDLE, BURST_TERM, WR_END: begin
                cnt_clk_res = 1'b1;
            end 
            WAIT_TRCD: begin
                cnt_clk_res = trcd_end;
            end 
            BURST_WRITE: begin
                cnt_clk_res = burst_end;
            end
            WAIT_TRP: begin
                cnt_clk_res = trp_end;
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
                if(wr_en) begin
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
                    next_state = WRITE;
                end else begin
                    next_state = WAIT_TRCD;
                end
            end
            
            WRITE: begin
                if(burst_end) begin
                    next_state = BURST_TERM;  //突发长度为1,下一个状态直接终止突发传输
                end else begin
                    next_state = BURST_WRITE;               
                end
            end
            
            BURST_WRITE: begin
                if(burst_end) begin
                    next_state = BURST_TERM;
                end else begin
                    next_state = BURST_WRITE;
                end
            end
            
            BURST_TERM: begin
                next_state = PRE_CHARG;
            end
            
            PRE_CHARG: begin
                next_state = WAIT_TRP;
            end
            
            WAIT_TRP: begin
                if(trp_end) begin
                    next_state = WR_END;
                end else begin
                    next_state = WAIT_TRP;
                end
            end
            
            WR_END: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
            
        endcase
    end
    
    //处理突发传输溢出(突发连续写入的地址空间跨越不同行, 则需要暂停当前行写入, 并在新行重新进行发起写操作)
    
    //column_addr_reg
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            column_addr_reg <= 13'b0;
        end else if(state == WRITE) begin //寄存列首地址
            column_addr_reg <= column_addr;
        end else begin
            column_addr_reg <= column_addr_reg;
        end
    end
    
    
    //wr_overflow
    always@(*) begin
        case(state) 
            WRITE: begin //WRITE状态下的地址就是列首地址
                wr_overflow = (column_addr + wr_burst_len > MAX_COLUMN)?1'b1:1'b0;
            end
            
            BURST_WRITE: begin //使用寄存的列首地址
                wr_overflow = (column_addr_reg + wr_burst_len > MAX_COLUMN)?1'b1:1'b0;
            end
            
            default: begin //其它状态不关心overflow与否
                wr_overflow = 1'b0;
            end
        endcase
    end
    
    //burst_len
    always@(*) begin
        case(state) 
            WRITE: begin //WRITE状态下的地址就是列首地址
                if(wr_overflow) begin
                    burst_len = MAX_COLUMN - column_addr;
                end else begin      //没有溢出时是wr_burst_len
                    burst_len = wr_burst_len;
                end
            end
            
            BURST_WRITE: begin //使用寄存的列首地址
                if(wr_overflow) begin
                    burst_len = MAX_COLUMN - column_addr_reg;
                end else begin     //没有溢出时是wr_burst_len
                    burst_len = wr_burst_len;
                end
            end
            
            default: begin //其它状态使用输入的突发长度
                burst_len = wr_burst_len;
            end
        endcase
    end    
    
    
    
    //输出
    //wr_cmd
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_cmd <= NOP_CMD;
        end else case(state) 
            ACTIVE: begin
                wr_cmd <= ACTIVE_CMD;
            end
            WRITE: begin
                wr_cmd <= WRITE_CMD;
            end
            BURST_TERM: begin
                wr_cmd <= BURST_TERM_CMD;
            end
            PRE_CHARG: begin
                wr_cmd <= PRE_CHARG_CMD;
            end
            default: begin
                wr_cmd <= NOP_CMD;
            end
        endcase
    end
    
    //wr_bank_addr
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_bank_addr <= 2'b11;
        end else case(state)
            ACTIVE, WRITE, PRE_CHARG: begin
                wr_bank_addr <= bank_addr; //高两位是bank地址
            end
            default: begin
                wr_bank_addr <= 2'b11;
            end
        endcase
    end
    
    //wr_sdram_addr
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_sdram_addr <= 13'h1fff;
        end else case(state)
            ACTIVE: begin
                wr_sdram_addr <= row_addr; //激活地址总线是行地址
            end
            PRE_CHARG: begin
                wr_sdram_addr <= 13'h1dff; //预充电时A[10]为低电平,则只预充电选中bank
            end
            WRITE: begin
                wr_sdram_addr <= column_addr; //写操作时是列首地址
            end
            default: begin
                wr_sdram_addr <= 13'h1fff;
            end
        endcase
    end    
    
    //wr_sdram_data
    assign wr_sdram_data = (wr_sdram_en)?wr_data:16'b0;
    
    //wr_end
    assign wr_end = (state == WR_END)?1'b1:1'b0;
    
    //wr_ack
    assign wr_ack = (state == WRITE || state == BURST_WRITE)?1'b1:1'b0;
    
    //wr_sdram_en
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_sdram_en <= 1'b0;
        end else begin
            wr_sdram_en <= wr_ack;
        end
    end
    
endmodule
