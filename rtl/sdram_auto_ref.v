`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/05 15:01:07
// Module Name: sdram_auto_ref
// Description: SDRAM的自动刷新逻辑的实现
//////////////////////////////////////////////////////////////////////////////////


module sdram_auto_ref(
        input   wire        clk             ,
        input   wire        rst_n           ,
        input   wire        init_end        ,   //初始化结束标志
        input   wire        aref_en         ,   //仲裁模块判定可以进行自动刷新
                    
        output  reg         aref_req        ,   //输出到仲裁模块的刷新请求
        output  reg [3:0]   aref_cmd        ,   //输出命令
        output  wire[12:0]  aref_addr       ,   //地址总线
        output  wire[1:0]   aref_bank_addr  ,   //bank 地址
        output  wire        aref_end            //自动刷新完成标志
    );
    
    //状态机状态定义
    parameter   IDLE        =   6'b000001,
                PRE_CHARG   =   6'b000010,
                WAIT_TRP    =   6'b000100,
                AUTO_REF    =   6'b001000,
                WAIT_TRFC   =   6'b010000,
                AREF_END    =   6'b100000;
                
    //计时器计数周期定义
    parameter   TPR         =   3'd2            ,
                TRFC        =   3'd7            ,
                TREFM       =   10'd749         ; //自动刷新周期
                //64ms完成8192行的刷新,则每7812.5ns要完成一次刷新, 时钟频率100M, 则刷新最大周期为781.25
                
    //命令定义
    parameter   NOP_CMD       = 4'b1000,
                PRE_CHARG_CMD = 4'b0010,
                AUTO_REF_CMD  = 4'b0001;
    
    //内部信号
    reg [5:0]   next_state  ;
    reg [5:0]   state       ;
    reg [9:0]   cnt_ref     ;   //自动刷新周期计数器
    wire        aref_ack    ;   //自动刷新响应信号,为高电平时,撤销自动刷新请求
    reg [2:0]   cnt_clk     ;   //等待时间计数器,计数Trp\TRFC
    reg         cnt_clk_res ;   //cnt_clk的复位信号,高电平有效
    wire        trp_end     ;   //Trp等待完成标志
    wire        trfc_end    ;
    reg         cnt_aref    ;   //AUTO_REF命令完成次数计数器
    
    //cnt_ref
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_ref <= 10'd0;
        end else if(init_end && cnt_ref == TREFM) begin
            cnt_ref <= 10'd0;
        end else if(init_end) begin
            cnt_ref <= cnt_ref + 10'd1;
        end else begin
            cnt_ref <= 10'd0;
        end
    end
    
    //aref_ack
    //仲裁模块判定可以进行自动刷新,则下一周期不再向仲裁模块发送刷新请求
    assign aref_ack = (state == PRE_CHARG)?1'b1:1'b0;
    
    
    //aref_req
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            aref_req <= 1'b0;
        end else if(cnt_ref == TREFM) begin  //需要发起自动刷新
            aref_req <= 1'b1;
        end else if(aref_ack) begin  //开始自动刷新操作,关闭自动刷新请求
            aref_req <= 1'b0;
        end else begin
            aref_req <= aref_req;
        end
    end
    
    
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
    
    //等待时间完成标志
    assign trp_end  = (state == WAIT_TRP && cnt_clk == TPR)?1'b1:1'b0;
    assign trfc_end = (state == WAIT_TRFC && cnt_clk == TRFC)?1'b1:1'b0;
    
    //状态机更新
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    //状态机次态
    always@(*) begin
        case(state) 
            IDLE: begin
                if(aref_en) begin
                    next_state = PRE_CHARG;
                end else begin
                    next_state = IDLE;
                end
            end
            
            PRE_CHARG: begin
                next_state = WAIT_TRP;
            end
            
            WAIT_TRP: begin
                if(trp_end) begin
                    next_state = AUTO_REF;
                end else begin
                    next_state = WAIT_TRP;
                end
            end
            
            AUTO_REF: begin
                next_state = WAIT_TRFC;
            end
            
            WAIT_TRFC: begin
                if(trfc_end && cnt_aref == 1'b1) begin
                //Trfc等待完成,并且已经刷新过一次,这次是第二次,可以进入下一状态
                    next_state = AREF_END;
                end else if(trfc_end && cnt_aref == 1'b0) begin
                //刷新次数不够
                    next_state = AUTO_REF;
                end else begin
                    next_state = WAIT_TRFC;
                end
            end
            
            AREF_END: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    //cnt_clk_res
    always@(*) begin
        case(state) 
            IDLE, AREF_END: begin
                cnt_clk_res = 1'b1;
            end 
            
            PRE_CHARG, AUTO_REF: begin
                cnt_clk_res = 1'b0;
            end
            
            WAIT_TRP: begin
                cnt_clk_res = trp_end;
            end
            
            WAIT_TRFC: begin
                cnt_clk_res = trfc_end;
            end
            
            default: begin
                cnt_clk_res = 1'b1;
            end
        endcase
    end
    
    //cnt_aref
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_aref <= 1'b0;
        end else if(trfc_end && cnt_aref == 1'b1) begin
            cnt_aref <= 1'b0;
        end else if(trfc_end) begin
            cnt_aref <= cnt_aref + 1'b1;
        end else begin
            cnt_aref <= cnt_aref;
        end
    end
    
    //aref_cmd
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            aref_cmd <= NOP_CMD;
        end else case(state)
            PRE_CHARG: begin
                aref_cmd <= PRE_CHARG_CMD;
            end
            
            AUTO_REF: begin
                aref_cmd <= AUTO_REF_CMD;
            end 
            
            default: begin
                aref_cmd <= NOP_CMD;
            end
        endcase
    end
    
    //自动刷新时不使用地址总线,预充电时将aref_addr[10]置为高电平,即可对所有bank预充电
    assign aref_addr        = 13'h1fff;
    assign aref_bank_addr   = 2'b11;
    
    //aref_end
    assign aref_end = (state == AREF_END)?1'b1:1'b0;
    
                
endmodule
