//      Author:Nathan Blais
//Date Created:2020-02-16

#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module DistanceVectorRoutingP
{
    //Provides the SimpleSend interface in order to flood packets
    provides interface DistanceVectorRouting;
    //Uses the SimpleSend interface to forward recieved packet as broadcast
    uses interface SimpleSend as Sender;
    //Uses the Receive interface to determine if received packet is meant for me.
    uses interface Receive as Receiver;
    uses interface AMPacket;
    //Uses the Queue interface to determine if packet recieved has been seen before
    uses interface List<pack> as PacketsList;
    //NOTE:remember to store src & seq for each node

    uses interface NeighborDiscovery;

     uses interface List<route> as Routes;

    //NOTE: Wire a timmer
}

implementation
{

    //NOTE: Make a run command that starts after a random ammount of time.
    

//Broadcast packet
	command error_t DistanceVectorRouting.send(pack msg, uint16_t dest)
	{
		//Attempt to send the packet
		dbg(ROUTING_CHANNEL, "Sending from Router\n");

		if (call Sender.send(msg, AM_BROADCAST_ADDR) == SUCCESS)
		{
			return SUCCESS;
		}
		return FAIL;
	}

//Event signaled when a DVRouter recieves a packet
   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      dbg(ROUTING_CHANNEL, "Packet Received in VRouter\n");
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;



         
         dbg(ROUTING_CHANNEL, "Package Payload: %s\n", myMsg->payload);
         return msg;
      }
      dbg(ROUTING_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }



/*
The routine that updates the local node’s routing table based on a new route is given by mergeRoute. Although not shown, a timer function peri- odically scans the list of routes in the node’s routing table, decrements the TTL (time to live) field of each route, and discards any routes that have a time to live of 0. Notice, however, that the TTL field is reset to MAX TTL any time the route is reconfirmed by an update message from a neighboring node. */
    void
        mergeRoute(Route * new)
    {
        int i;
        for (i = 0; i < numRoutes; ++i)
        {
            if (new->Destination == routingTable[i].Destination)
            {
                if (new->Cost + 1 < routingTable[i].Cost)
                {
                    /* found a better route: */
                    break;
                }
                else if (new->NextHop == routingTable[i].NextHop)
                {
                }
            }
            /* metric for current next-hop may have changed: */
            break;
        }
        else
        {
            /* route is uninteresting---just ignore it */
            return;
        }
        if (i == numRoutes)
        {
            /* this is a completely new route; is there room
             for it? */
            if (numRoutes < MAXROUTES)
            {
                ++numRoutes;
            }
            else
            {
                /* can't fit this route in table so give up */
                return;
            }
        }
        routingTable[i] = *new;
        /* reset TTL */
        routingTable[i].TTL = MAX_TTL;
        /* account for hop to get to next node */ ++routingTable[i].Cost;
    }
    /*
    Finally, the procedure updateRoutingTable is the main routine that calls mergeRoute to incorporate all the routes contained in a routing update that is received from a neighboring node. */
    void updateRoutingTable(Route * newRoute, int numNewRoutes)
    {
        int i;
        for (i = 0; i < numNewRoutes; ++i)
        {

            mergeRoute(&newRoute[i]);
        }
    }
}