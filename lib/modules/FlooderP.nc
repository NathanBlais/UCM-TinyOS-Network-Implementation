#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module FlooderP{
	//Provides the SimpleSend interface in order to flood packets
	provides interface Flooder;
	//Uses the SimpleSend interface to forward recieved packet as broadcast
	uses interface SimpleSend as Sender;
	//Uses the Receive interface to determine if received packet is meant for me.
	uses interface Receive as Receiver;
}

implementation {


	//Broadcast packet
	command error_t Flooder.send(pack msg, uint16_t dest) { 			
		//Attempt to send the packet		
		dbg(FLOODING_CHANNEL, "Sending from Flooder\n");

		if( call Sender.send(msg, AM_BROADCAST_ADDR) == SUCCESS ) {
			return SUCCESS;
		}
		return FAIL;				
	}

	//Event signaled when a node recieves a packet
	event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len) {
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;	
    }
}