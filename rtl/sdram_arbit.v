`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/07 19:31:01
// Module Name: sdram_arbit
// Description: 仲裁模块,决定当前执行SDRAM读、写、初始化、自动刷新这几类基本操作的一类
//////////////////////////////////////////////////////////////////////////////////

module sdram_arbit(
        input   wire        clk             ,
        input   wire        rst_n           ,
                
        //sdram_init模块数据通道      
        input   wire [3:0]  init_cmd        ,
        input   wire [1:0]  init_bank_addr  ,
        input   wire [12:0] init_addr       ,
        input   wire        init_end        ,

        //sdram_auto_ref模块数据通道      
        input   wire [3:0]  aref_cmd        ,
        input   wire [1:0]  aref_bank_addr  ,
        input   wire [12:0] aref_addr       ,
        input   wire        aref_end        ,
        input   wire        aref_req        ,

        //sdram_write模块数据通道      
        input   wire [3:0]  wr_cmd          ,
        input   wire [1:0]  wr_bank_addr    ,
        input   wire [12:0] wr_sdram_addr   ,
        input   wire        wr_end          ,
        input   wire        wr_req          ,        

        //sdram_read模块数据通道      
        input   wire [3:0]  rd_cmd          ,
        input   wire [1:0]  rd_bank_addr    ,
        input   wire [12:0] rd_sdram_addr   ,
        input   wire        rd_end          ,
        input   wire        rd_req          ,    

        //输出操作使能信号
        output  reg         aref_en         ,
        output  reg         wr_en           ,
        output  reg         rd_en           ,
        
        //输出到SDRAM的信号
        output  wire        sdram_cs_n      ,
        output  wire        sdram_ras_n     ,
        output  wire        sdram_cas_n     ,
        output  wire        sdram_we_n      ,
        output  reg  [1:0]  sdram_ba        ,
        output  reg  [12:0] sdram_addr      

    );
    
    //状态机状态定义
    parameter   IDLE    =   5'b00001,
                AREF    =   5'b00010,
                WRITE   =   5'b00100,
                READ    =   5'b01000,
                ARBIT   =   5'b10000;
    
    //命令定义
    parameter   NOP_CMD =   4'b1000;
    //中间信号            
    reg [4:0]   state           ;
    reg [4:0]   next_state      ;
    reg [3:0]   sdram_cmd       ;
    
    
    //三段式状态机
    
    //state
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    //next_state
    always@(*) begin
        case(state) 
            IDLE: begin
                if(init_end) begin
                    next_state = ARBIT;
                end else begin
                    next_state = IDLE;
                end
            end
            
            ARBIT: begin
                if(aref_req) begin //自动刷新请求优先级最高
                    next_state = AREF;
                end else if(wr_req) begin
                    next_state = WRITE;
                end else if(rd_req) begin
                    next_state = READ; //读请求优先级最低
                end else begin
                    next_state = ARBIT;
                end
            end
            
            AREF: begin
                if(aref_end) begin
                    next_state = ARBIT;
                end else begin
                    next_state = AREF;
                end
            end
            
            WRITE: begin
                if(wr_end) begin
                    next_state = ARBIT;
                end else begin
                    next_state = WRITE;
                end
            end
            
            READ: begin
                if(rd_end) begin
                    next_state = ARBIT;
                end else begin
                    next_state = READ;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    //依据状态机状态确定输出
    always@(*) begin
        case(state)
            IDLE: begin //IDLE状态下进行初始化
                sdram_cmd   = init_cmd      ;
                sdram_addr  = init_addr     ;
                sdram_ba    = init_bank_addr;
                wr_en       = 1'b0          ;
                rd_en       = 1'b0          ;
                aref_en     = 1'b0          ;
            end
            
            ARBIT: begin
                sdram_cmd   = NOP_CMD       ;
                sdram_addr  = 13'h1fff      ;
                sdram_ba    = 2'b11         ;
                wr_en       = 1'b0          ;
                rd_en       = 1'b0          ;
                aref_en     = 1'b0          ;  
            end
            
            AREF: begin
                sdram_cmd   = aref_cmd      ;
                sdram_addr  = aref_addr     ;
                sdram_ba    = aref_bank_addr;  
                wr_en       = 1'b0          ;
                rd_en       = 1'b0          ;
                aref_en     = 1'b1          ;                  
            end
            
            WRITE: begin
                sdram_cmd   = wr_cmd        ;
                sdram_addr  = wr_sdram_addr ;
                sdram_ba    = wr_bank_addr  ; 
                wr_en       = 1'b1          ;
                rd_en       = 1'b0          ;
                aref_en     = 1'b0          ;                  
            end
            
            READ: begin
                sdram_cmd   = rd_cmd        ;
                sdram_addr  = rd_sdram_addr ;
                sdram_ba    = rd_bank_addr  ; 
                wr_en       = 1'b0          ;
                rd_en       = 1'b1          ;
                aref_en     = 1'b0          ;                
            end
            
            default: begin //默认是IDLE状态
                sdram_cmd   = init_cmd      ;
                sdram_addr  = init_addr     ;
                sdram_ba    = init_bank_addr;  
                wr_en       = 1'b0          ;
                rd_en       = 1'b0          ;
                aref_en     = 1'b0          ;                
            end
        endcase
    end
    
    //依据命令生成控制信号
    assign sdram_cs_n      = sdram_cmd[3];
    assign sdram_ras_n     = sdram_cmd[2];
    assign sdram_cas_n     = sdram_cmd[1];
    assign sdram_we_n      = sdram_cmd[0]; 


                                         
endmodule
