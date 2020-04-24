interface CommandHandler{
   // Events
   event void ping(uint16_t destination, uint8_t *payload);
   event void printNeighbors();
   event void printRouteTable();
   event void printLinkState();
   event void printDistanceVector();
   event void setTestServer(uint8_t port);
   event void setTestClient(uint8_t srcPort, uint8_t destination, uint8_t destPort, uint8_t *payload);
   event void cmdClientClose(uint8_t address, uint8_t srcPort, uint8_t destination, uint8_t destPort);
   event void cmdServerRead(uint8_t port, uint16_t  bufflen);
   event void setAppServer();
   event void setAppClient();
}
