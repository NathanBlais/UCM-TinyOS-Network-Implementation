#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module NeighborDiscoveryP
{

    //Provides the SimpleSend interface in order to neighbor discover packets
    provides interface NeighborDiscovery;
    //Uses SimpleSend interface to forward recieved packet as broadcast
    uses interface SimpleSend as Sender;
    //Uses the Receive interface to determine if received packet is meant for me.
	uses interface Receive as Receiver;
	//Uses the Queue interface to determine if packet recieved has been seen before
	uses interface List<pack> as KnownPacketsList;
    uses interface Timer<TMilli> as periodicTimer;
   
}


implementation
{

   // call periodicTimer.startPeriodic(100); 
    pack sendPackage; //at the moment not sure
   // pack 
    bool inThere;
    void makePack(pack * Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t seq, uint16_t protocol, uint8_t * payload, uint8_t length);
	bool isInList(pack packet);
	error_t addToList(pack packet);
    void printNeighborhood();

 
    command error_t NeighborDiscovery.run()
	{
         call periodicTimer.startPeriodic(100);
	}

    event void periodicTimer.fired()
    {
        dbg(NEIGHBOR_CHANNEL, "Sending from NeighborDiscovery\n");
        makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 1,0 , PROTOCOL_PING, "HOLA AMIGO" , PACKET_MAX_PAYLOAD_SIZE);
		call Sender.send(sendPackage, AM_BROADCAST_ADDR);
    }


    event message_t *Receiver.receive(message_t * msg, void *payload, uint8_t len)
    {
        if (len == sizeof(pack)) //check if there's an actual packet
        {
           // dbg(NEIGHBOR_CHANNEL, "I'm looking at neighbordiscovery code \n");
            pack *contents = (pack*) payload;

            if (PROTOCOL_PING == contents-> protocol) //got a message, not a reply
            {
                //check if in list? no

                //for now just send a message back

                if (contents->TTL == 1)
                {

                contents->TTL = contents->TTL - 1;

                    //inThere = isInList(*contents);

                   // if (inThere == TRUE)
                   // {
                        // do nothing
                       // return msg;
                   // }

                      

                makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 1, contents->seq, PROTOCOL_PINGREPLY, (uint8_t *)contents->payload, PACKET_MAX_PAYLOAD_SIZE);
                dbg(GENERAL_CHANNEL, "Sending Ping Reply \n");
                call Sender.send(sendPackage, AM_BROADCAST_ADDR);
                return msg;

                }

                else 
                {
                    return msg;
                }
            }

            else if (PROTOCOL_PINGREPLY == contents->protocol) //we made replies be of one
            {
                if (contents->TTL == 1) //traveled one node, has not yet been subtracted
                {
                    //check destination here
                    
                    contents->TTL = contents->TTL - 1;

                    inThere = isInList(*contents);

                    if (inThere == TRUE)
                    {
                        // do nothing
                        return msg;
                    }

                    else 
                    {

                        addToList(*contents);
                        printNeighborhood();
                        return msg;
                           //dbg(NEIGHBOR_CHANNEL, "This packet is a neighbor of the node %d and it's node number is &d", TOS_NODE_ID,  );

                    }

                }

                else 
                {
                    return msg; //kill it do nothing
                }
            }

        }

        dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
		return msg;

    }


void makePack(pack * Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t seq, uint16_t protocol, uint8_t * payload, uint8_t length)
	{
		Package->src = src;
		Package->dest = dest;
		Package->TTL = TTL;
		Package->seq = seq;
		Package->protocol = protocol;
		memcpy(Package->payload, payload, length);
	}

	//Function to check if packet matches a packet in KnownPacketsList
	bool isInList(pack packet)
	{
		uint16_t size = call KnownPacketsList.size();
		uint8_t i;
		pack pkt;

		if (!call KnownPacketsList.isEmpty())
		{
			for (i = 0; i < size; i++)
			{
				pkt = call KnownPacketsList.get(i);
				if (packet.src == pkt.src && packet.seq == pkt.seq)
				{
					return TRUE;
				}
			}
		}
		return FALSE;
	}

	//Function to add packet to KnownPacketsList. If the list is full the last element is
	//removed and the new packet added. Does not check if a packet is already in the list.
	error_t addToList(pack packet)
	{
		//uint16_t size = call KnownPacketsList.size();

		if (call KnownPacketsList.pushback(packet) == TRUE)
		{
			return SUCCESS;
		}
		else
		{
			call KnownPacketsList.popfront();
			if (call KnownPacketsList.pushback(packet) == TRUE)
			{
				return SUCCESS;
			}
			else
			{
				return FAIL;
			}
		}
	}


void printNeighborhood ()
{
    uint16_t size = call KnownPacketsList.size();
	uint8_t i;
    pack pkt;

    for ( i = 0; i < size; i ++)
   
    {
        pkt = call KnownPacketsList.get(i);
        dbg(NEIGHBOR_CHANNEL, "This packet is a neighbor of the node %d and it's node number is %d \n", TOS_NODE_ID, pkt.src  );
    }
}

} // for implementation