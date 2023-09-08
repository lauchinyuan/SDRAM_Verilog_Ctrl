`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/04 16:33:44
// Module Name: sdram_init
//////////////////////////////////////////////////////////////////////////////////
module sdram_init(
        input   wire        clk             ,
        input   wire        rst_n           ,
        output  reg [3:0]   init_cmd        ,
        output  reg [1:0]   init_bank_addr  ,
        output  wire        init_end        ,
        output  reg [12:0]  init_addr       
    );
    
    //中间变量声明
    reg [7:0]       state       ;
    reg [14:0]      cnt_200us   ; //200us计数器

    reg [2:0]       cnt_clk     ;
    reg             cnt_clk_res ;
    wire            wait_end    ;
    wire            trp_end     ;
    wire            tmrd_end    ;
    wire            trfc_end    ;
    reg [2:0]       cnt_aref    ;
    
    
    //状态机
    reg [7:0]       next_state  ;
    
    //状态定义
    parameter IDLE      = 8'b00000001, 
              PRE_CHARG = 8'b00000010,  //预充电
              WAIT_TRP  = 8'b00000100,
              AUTO_REF  = 8'b00001000,  //自动刷新
              WAIT_TRFC = 8'b00010000,
              MOD_REG   = 8'b00100000,  //模式寄存器配置
              WAIT_TMRD = 8'b01000000,
              INIT_END  = 8'b10000000;  //初始化完成
              
    //计时参数定义
    parameter CNT_200U = 15'd19999   ,
              CNT_TRP  = 3'd2        ,
              CNT_TRFC = 3'd7        ,
              CNT_TMRD = 3'd3        ;
              
    //命令定义
    parameter NOP_CMD       = 4'b1000,
              PRE_CHARG_CMD = 4'b0010,
              AUTO_REF_CMD  = 4'b0001,
              MOD_REG_CMD   = 4'b0000;
    
    //潜伏期参数
    parameter CAS           = 3'b011 ;
              
    //寄存器配置参数
    parameter MOD_ADDR      = {3'b0,1'b0,2'b0,CAS,1'b0,3'b111}  ; //配置模式寄存器的值
              
              
    //中间信号定义,用于状态机状态转换条件判断
    //cnt_200us
    //上电后至少200us才能进行预充电命令写入
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin    
            cnt_200us <= 15'b0;
        end else if(wait_end) begin
            cnt_200us <= 15'b0;
        end else if(state == IDLE) begin
            cnt_200us <= cnt_200us + 15'd1;
        end else begin
            cnt_200us <= cnt_200us;
        end
    end
    
    
    //wait_end
    //完成200us等待标志
    assign wait_end = (state == IDLE && cnt_200us == CNT_200U)?1'b1:1'b0;
    
    //trp_end
    //Trp等待完成信号
    assign trp_end = (state == WAIT_TRP && cnt_clk == CNT_TRP)?1'b1:1'b0;
    
    //trfc_end
    assign trfc_end = (state == WAIT_TRFC && cnt_clk == CNT_TRFC)?1'b1:1'b0;
    
    //tmrd_end
    assign tmrd_end = (state == WAIT_TMRD && cnt_clk == CNT_TMRD)?1'b1:1'b0;
    
    
    //cnt_clk_res
    //cnt_clk计数器复位信号,高电平有效
    always@(*) begin
        case(state)
            IDLE: begin
                cnt_clk_res = 1'b1;
            end
            WAIT_TRP: begin
                if(trp_end) begin
                    cnt_clk_res = 1'b1;
                end else begin
                    cnt_clk_res = 1'b0;
                end
            end
            WAIT_TRFC: begin
                if(trfc_end) begin
                    cnt_clk_res = 1'b1;
                end else begin
                    cnt_clk_res = 1'b0;
                end
            end   
            WAIT_TMRD: begin
                if(tmrd_end) begin
                    cnt_clk_res = 1'b1;
                end else begin
                    cnt_clk_res = 1'b0;
                end
            end      
            INIT_END: begin
                cnt_clk_res = 1'b1;
            end 
            default: begin
                cnt_clk_res = 1'b0;
            end        
        endcase
    end
    
/*     always@(*) begin
        case(state)
            IDLE, INIT_END: begin
                cnt_clk_res = 1'b1;
            end
            PRE_CHARG, WAIT_TRP, AUTO_REF, WAIT_TRFC, MOD_REG, WAIT_TMRD: begin
                cnt_clk_res = tmrd_end | trfc_end | trp_end;
            end
            default: begin
                cnt_clk_res = 1'b1;
            end
        endcase
    end */
    
    //等待时间计数器
    //cnt_clk
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_clk <= 3'd0;
        end else if(cnt_clk_res) begin
            cnt_clk <= 3'd0;
        end else begin
            cnt_clk <= cnt_clk + 3'd1;
        end
    end
    
    //自刷新次数计数器,SDRAM要求至少需要自刷新两次
    //cnt_aref
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_aref <= 3'd0;
        end else if(trfc_end) begin
            cnt_aref <= cnt_aref + 3'd1;
        end else begin
            cnt_aref <= cnt_aref;
        end
    end
    
    
    //状态机次态变换
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    //状态机次态变换
    //next_state
    always@(*) begin
        case(state)
            IDLE: begin
                if(wait_end) begin  //200us等待完成
                    next_state = PRE_CHARG;
                end else begin
                    next_state = IDLE;
                end
            end
            PRE_CHARG: begin
                next_state = WAIT_TRP;
            end
            WAIT_TRP: begin
                if(trp_end) begin  //Trp等待完毕
                    next_state = AUTO_REF;
                end else begin
                    next_state = WAIT_TRP;
                end
            end
            AUTO_REF: begin
                next_state = WAIT_TRFC;
            end
            WAIT_TRFC: begin
                if(trfc_end && cnt_aref >= 3'd7) begin //完成Trfc等待时间,并且已经自刷新多次
                    next_state = MOD_REG;
                end else if(trfc_end) begin ////完成Trfc等待时间,但自刷新次数不够
                    next_state = AUTO_REF;
                end else begin
                    next_state = WAIT_TRFC;
                end
            end
            MOD_REG: begin
                next_state = WAIT_TMRD;
            end
            WAIT_TMRD: begin
                if(tmrd_end) begin  //完成Tmrd等待时间
                    next_state = INIT_END;
                end else begin
                    next_state = WAIT_TMRD;
                end
            end
            INIT_END: begin
                next_state = INIT_END;  //已经完成一次初始化, 不再更新状态
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end //always end
    
    //命令
    //init_cmd
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            init_cmd <= NOP_CMD;
        end else case(state) 
            PRE_CHARG: begin  
                init_cmd <= PRE_CHARG_CMD;//预充电命令
            end
            AUTO_REF: begin
                init_cmd <= AUTO_REF_CMD;//自动刷新命令
            end
            MOD_REG: begin
                init_cmd <= MOD_REG_CMD; //寄存器模式配置命令
            end
            default: begin
                init_cmd <= NOP_CMD;     //空指令
            end
        endcase
    
    end
    
    //init_bank_addr
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            init_bank_addr <= 2'b11;
        end else if(state == MOD_REG) begin //在配置模式寄存器时bank地址为00
            init_bank_addr <= 2'b00;
        end else begin
            init_bank_addr <= 2'b11;
        end
    end
    
    //地址总线, 在init时,只有模式配置状态下才实际起作用
    //init_addr
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            init_addr <= 13'h1fff; //全部拉高,在预充电状态下表示预充电所有bank
        end else if(state == MOD_REG) begin
            init_addr <= MOD_ADDR;
        end else begin
            init_addr <= 13'h1fff; //全部拉高
        end
    end
    
    //初始化完成标志
    //init_end
    assign init_end = (state == INIT_END)?1'b1:1'b0;
    
endmodule
