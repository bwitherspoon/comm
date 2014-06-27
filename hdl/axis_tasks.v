task reset;
    begin
      rst = 0;
      @(posedge clk);
      #1 rst = 1;
    end
endtask

task automatic send(input [SEND_WIDTH-1:0] data);
    begin
        i_tdata = data;
        i_tvalid = 1'b1;
        repeat (10) @(posedge clk)
            if (i_tready == 1'b1) begin
                #1 i_tvalid = 1'b0;
                disable send;
            end
        $display("ERROR: send() timeout waiting on tready");
        $finish;
    end
endtask

task automatic recv(output [RECV_WIDTH-1:0] mem);
    begin
        repeat (10) @(posedge clk)
            if (o_tvalid == 1'b1) begin
                mem = o_tdata;
                #1 disable recv;
            end
        $display("ERROR: recv() timeout waiting on tvalid");
        $finish;
    end
endtask
