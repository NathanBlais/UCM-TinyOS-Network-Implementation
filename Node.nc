/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;
   uses interface Flooder;

   uses interface CommandHandler;
   //uses interface Boot;
   uses interface NeighborDiscovery;

   uses interface DistanceVectorRouting;
}

implementation{
   pack sendPackage;
   am_addr_t nodes[10];
   uint16_t SEQ_NUM=1;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t seq, uint16_t protocol, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted before debugging \n");
   }



   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
      call NeighborDiscovery.run();
      call DistanceVectorRouting.run();

   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      dbg(GENERAL_CHANNEL, "Packet Received in Node\n");
      if(len==sizeof(pack)){
         pack *contents = (pack *)payload;

			if (contents->TTL == 0){ //Kill the packet if TTL is 0
				//do nothing
            	return msg;
         }
            //Check if the packet is meant for the current node
			if (contents->dest == TOS_NODE_ID)
			{ //Check the packet's protocol number
				if (PROTOCOL_PING == contents->protocol)
				{
					dbg(GENERAL_CHANNEL, "Ping Message:%s\n", contents->payload);
					makePack(&sendPackage, TOS_NODE_ID, contents->src, MAX_TTL, contents->seq, PROTOCOL_PINGREPLY, (uint8_t *)contents->payload, PACKET_MAX_PAYLOAD_SIZE);
					dbg(GENERAL_CHANNEL, "Sending Ping Reply to %d\n", contents->src);
					call Sender.send(sendPackage, call DistanceVectorRouting.GetNextHop(contents->src));
				}
				else if (PROTOCOL_PINGREPLY == contents->protocol)
				{
					dbg(GENERAL_CHANNEL, "Ping Reply Recived from %d\n", contents->src);
					dbg(GENERAL_CHANNEL, "Package Payload: %s\n", contents->payload);
				}
				else
					dbg(GENERAL_CHANNEL, "Recived packet with incorrect Protocol\n");
			}
			else //the packet is not meant for the current node
			{
				contents-> TTL = (contents->TTL) - 1; //Reduce TTL
				
				dbg(ROUTING_CHANNEL, "Packet is not ment for current node. Passing it on.\n");

	         if (contents->protocol == PROTOCOL_PING || contents->protocol == PROTOCOL_PINGREPLY){
               call Sender.send(*contents, call DistanceVectorRouting.GetNextHop(contents->dest));
            }
            else{
               dbg(GENERAL_CHANNEL, "Recived packet with incorrect Protocol\n");
            }
			}
         //dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, SEQ_NUM, PROTOCOL_PING, payload, PACKET_MAX_PAYLOAD_SIZE);
      SEQ_NUM++;
      //call Sender.send(sendPackage, destination);
      //call Flooder.send(sendPackage, destination);

      call Sender.send(sendPackage, call DistanceVectorRouting.GetNextHop(destination));
   }


   
   event void CommandHandler.printNeighbors(){call NeighborDiscovery.print();}

   event void CommandHandler.printRouteTable(){call DistanceVectorRouting.print();}

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t seq, uint16_t protocol, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}
