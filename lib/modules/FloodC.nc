#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module FloodC{
	//Provides the SimpleSend interface in order to flood packets
	provides interface Flooder;
	//Uses the SimpleSend interface to forward recieved packet as broadcast
	uses interface SimpleSend as Sender;
	//Uses the Receive interface to determine if received packet is meant for me.
	uses interface Receive as Receiver;
	//Uses the Queue interface to determine if packet recieved has been seen before
	//uses interface List<pack> as KnownList;
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
      
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         //pack pkt = *myMsg;	//Used to pass into the list helper functions above
         
         //dbg(FLOODING_CHANNEL, "Packet received. Source: %d Destination: %d.\n", myMsg->src, myMsg->dest);
         
         //If I am the original sender or have seen the packet before, drop it
         if((myMsg->src == TOS_NODE_ID)) {
         	//dbg(FLOODING_CHANNEL, "Dropping packet.\n");
         	return msg;
         }
             		
     		//If I am the intended receiver, read packet. Send a reply to original sender
     		if(myMsg->dest == TOS_NODE_ID) {
	         //Note that we have seen this packet.. not needed
	         //addToList(pkt);
	         //If packet is a ping reply, done
	         if(myMsg->protocol == PROTOCOL_PINGREPLY) {
	         	dbg(FLOODING_CHANNEL, "Received ACK from %d\n", myMsg->src);
	         	return msg;
	         }
	         else {	//else send a ping reply
	         	dbg(FLOODING_CHANNEL, "Received package from %d\n", myMsg->src);
	        		dbg(FLOODING_CHANNEL, "Package Payload: %s\n", myMsg->payload);
	         
		         myMsg->dest = myMsg->src;
		         myMsg->src = TOS_NODE_ID;
		         myMsg->protocol = PROTOCOL_PINGREPLY;
		         
		         call Flooder.send(*myMsg, myMsg->dest);
				}
	         return msg;
	      }
	      //If not meant for me and hasnt been dropped, forward packet
	      else {
				//dbg(FLOODING_CHANNEL, "Packet not for me.\n");
	      	//dbg(FLOODING_CHANNEL, "Packet not known, adding to list.\n");
	      	//addToList(pkt);
	      	
	      	//dbg(FLOODING_CHANNEL, "Forwarding packet.\n");
	      	call Flooder.send(*myMsg, myMsg->dest); 
	      }
         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;		
	}

}