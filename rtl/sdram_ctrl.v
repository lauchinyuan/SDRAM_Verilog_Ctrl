`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/07 21:29:32
// Module Name: sdram_ctrl
// Description: SDRAM读写控制模块,自动进行初始化、自动刷新、读、写四种基本操作
//////////////////////////////////////////////////////////////////////////////////


module sdram_ctrl(
        input   wire        clk             ,
        input   wire        rst_n           ,
                
        //读操作相关输入信号     
        input   wire        rd_req          , //读请求
        input   wire [23:0] rd_addr         , //读地址, 2bit Bank_addr + 13bit Row_addr + 9bit Column_addr
        input   wire [9:0]  rd_burst_len    ,
        
        //写操作相关输入信号     
        input   wire        wr_req          , 
        input   wire [23:0] wr_addr         , 
        input   wire [15:0] wr_data         ,
        input   wire [9:0]  wr_burst_len    ,
                
        //读写ack输出       
        output  wire        rd_ack          , //rd_ack与有效读出数据对齐
        output  wire        wr_ack          , //wr_ack相对写入数据提前一个时钟周期拉高,以告知外部模块更新数据 
        
        //模块与SDRAM之间的交互总线
        output  wire        cke             ,  //SDRAM时钟使能  
        output  wire        sdram_cs_n      ,
        output  wire        sdram_ras_n     ,
        output  wire        sdram_cas_n     ,
        output  wire        sdram_we_n      ,
        output  wire [1:0]  sdram_ba        ,
        output  wire [12:0] sdram_addr      ,        
        inout   wire [15:0] sdram_dq        ,  //读写SDRAM的数据总线
        
        output  wire [15:0] rd_data            //从SDRAM中读到的数据
    );
    
    //内部连线定义
    //sdram_init模块相关连线
    wire [3:0]  init_cmd        ;
    wire [1:0]  init_bank_addr  ;
    wire [12:0] init_addr       ;
    wire        init_end        ;
    
    //sdram_aref模块相关连线
    wire        aref_en         ;
    wire [3:0]  aref_cmd        ;
    wire [1:0]  aref_bank_addr  ;
    wire [12:0] aref_addr       ;
    wire        aref_end        ;
    wire        aref_req        ;
    
    //sdram_write模块相关连线  
    wire        wr_en           ;
    wire [3:0]  wr_cmd          ;
    wire [1:0]  wr_bank_addr    ;
    wire [12:0] wr_sdram_addr   ;
    wire        wr_end          ;
    wire        wr_sdram_en     ;
    wire [15:0] wr_sdram_data   ;

    //sdram_read模块相关连线 
    wire        rd_en           ;
    wire [3:0]  rd_cmd          ;
    wire [1:0]  rd_bank_addr    ;
    wire [12:0] rd_sdram_addr   ;
    wire        rd_end          ;

    

    //仲裁模块例化
    sdram_arbit sdram_arbit_init(
        .clk             (clk             ),
        .rst_n           (rst_n           ),

        .init_cmd        (init_cmd        ),
        .init_bank_addr  (init_bank_addr  ),
        .init_addr       (init_addr       ),
        .init_end        (init_end        ),

        .aref_cmd        (aref_cmd        ),
        .aref_bank_addr  (aref_bank_addr  ),
        .aref_addr       (aref_addr       ),
        .aref_end        (aref_end        ),
        .aref_req        (aref_req        ),

        .wr_cmd          (wr_cmd          ),
        .wr_bank_addr    (wr_bank_addr    ),
        .wr_sdram_addr   (wr_sdram_addr   ),
        .wr_end          (wr_end          ),
        .wr_req          (wr_req          ),        

        .rd_cmd          (rd_cmd          ),
        .rd_bank_addr    (rd_bank_addr    ),
        .rd_sdram_addr   (rd_sdram_addr   ),
        .rd_end          (rd_end          ),
        .rd_req          (rd_req          ),    

        .aref_en         (aref_en         ),
        .wr_en           (wr_en           ),
        .rd_en           (rd_en           ),

        .sdram_cs_n      (sdram_cs_n      ),
        .sdram_ras_n     (sdram_ras_n     ),
        .sdram_cas_n     (sdram_cas_n     ),
        .sdram_we_n      (sdram_we_n      ),
        .sdram_ba        (sdram_ba        ),
        .sdram_addr      (sdram_addr      )
    );    
    
    //初始化模块例化
    sdram_init sdram_init_inst(
        .clk             (clk             ),
        .rst_n           (rst_n           ),
        .init_cmd        (init_cmd        ),
        .init_bank_addr  (init_bank_addr  ),
        .init_end        (init_end        ),
        .init_addr       (init_addr       )
    );    
    
    //自动刷新模块例化
    sdram_auto_ref sdram_auto_ref_inst(
        .clk             (clk             ),
        .rst_n           (rst_n           ),
        .init_end        (init_end        ),   
        .aref_en         (aref_en         ),   

        .aref_req        (aref_req        ),   
        .aref_cmd        (aref_cmd        ),   
        .aref_addr       (aref_addr       ),   
        .aref_bank_addr  (aref_bank_addr  ),   
        .aref_end        (aref_end        )    
    );
    
    //写模块例化
    sdram_write sdram_write_inst(
        .clk             (clk             ),
        .rst_n           (rst_n           ),
        .wr_en           (wr_en           ),
        .wr_addr         (wr_addr         ),  
        .wr_data         (wr_data         ),
        .wr_burst_len    (wr_burst_len    ),

        .wr_cmd          (wr_cmd          ),
        .wr_bank_addr    (wr_bank_addr    ),
        .wr_sdram_addr   (wr_sdram_addr   ),
        .wr_sdram_data   (wr_sdram_data   ),
        .wr_end          (wr_end          ),
        .wr_ack          (wr_ack          ),
        .wr_sdram_en     (wr_sdram_en     )
    );
    
    sdram_read sdram_read_inst(
        .clk             (clk             ),
        .rst_n           (rst_n           ),
        .rd_addr         (rd_addr         ),
        .rd_sdram_data   (sdram_dq        ),  //读模块的数据输入是dq数据线
        .rd_burst_len    (rd_burst_len    ),
        .rd_en           (rd_en           ),
                          
        .rd_ack          (rd_ack          ),
        .rd_cmd          (rd_cmd          ),
        .rd_bank_addr    (rd_bank_addr    ),
        .rd_sdram_addr   (rd_sdram_addr   ),
        .rd_end          (rd_end          ),
        .rd_data         (rd_data         )
    );
    
    
    //输入输出dq数据线,在有效数据写入SDRAM时,将数据设置为写入数据,否则设置为高阻态
    assign sdram_dq = (wr_sdram_en)?wr_sdram_data:16'hzzzz;
    
    //时钟使能信号始终为高电平
    assign cke = 1'b1;
    
    
endmodule
