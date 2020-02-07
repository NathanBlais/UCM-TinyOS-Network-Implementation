module FloodC{
        //Provides the SimpleSend interface in order to flood packets
        provides interface SimpleSend as Flooder;
        //Uses the SimpleSend interface to forward recieved packet as broadcast
	    uses interface SimpleSend as Sender;
	    //Uses the Receive interface to determine if received packet is meant for me.
	    uses interface Receive as Receiver;
	    ////Uses the Queue interface to determine if packet recieved has been seen before
	    //uses interface List<pack> as KnownList;
}

implementation {


	//Broadcast packet
	command error_t Flooder.send(pack msg, uint16_t dest) { 			
		//Attempt to send the packet		
		if( call Sender.send(msg, AM_BROADCAST_ADDR) == SUCCESS ) {
			return SUCCESS;
		}
		return FAIL;	
    }

	//Event signaled when a node recieves a packet
   event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len){
      dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }

}