
module Top;

    bit ACLK = 0;
    always #5 ACLK = ~ACLK;

    arb_if          arbif_write(ACLK);
    axi4            axi(arbif_write.axi);
    axi4_tb         axi_tb  (arbif_write.axi_tb);
    axi4_monitor    mon  (arbif_write.monitor);

endmodule

