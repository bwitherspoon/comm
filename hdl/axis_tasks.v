task reset;
    begin
      rst = 0;
      @(posedge clk);
      #1 rst = 1;
    end
endtask

task send(input [WIDTH-1:0] data);
  begin
    i_tdata = data;
    i_tvalid = 1'b1;
    @(posedge clk);
    #1 i_tvalid = 1'b0;
  end
endtask

