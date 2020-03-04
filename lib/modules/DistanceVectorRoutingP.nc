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
    //make temporary list

    uses interface Timer<TMilli> as periodicTimer;

    //NOTE: Wire a timmer
}

implementation
{
	pack sendPackage;
    uint8_t * neighbors; //Maximum of 20 neighbors?

    void updateRoutingTable(route * newRoutes, uint16_t size);

    void UpdateNeighborRoutingTable();

    void mergeRoute(route * newRoute);

    void makePack(pack * Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t seq, uint16_t protocol, uint8_t * payload, uint8_t length);



    command void DistanceVectorRouting.run()
    {
        call periodicTimer.startPeriodic(1000000); //add random #
    }

    event void periodicTimer.fired()
    {
        dbg(ROUTING_CHANNEL, "PeriodicTimer fired from Routing");
        // update Router list form neighbor list
        UpdateNeighborRoutingTable();

        //do Split Horizon with posion


        dbg(ROUTING_CHANNEL, "Sending from DVR\n");

        //optional - call a function to organize the list

        makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 1, SEQ_NUM, PROTOCOL_DV, memcpy(Routes), PACKET_MAX_PAYLOAD_SIZE);
        //call Sender.send(sendPackage, AM_BROADCAST_ADDR);
    }



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
   event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len){
      dbg(ROUTING_CHANNEL, "Packet Received in VRouter\n");
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;



         dbg(ROUTING_CHANNEL, "Package Payload: %s\n", myMsg->payload);
         return msg;
      }
      dbg(ROUTING_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }

    //Takes nighbor info and converts it to a Routing table for the updateRoutingTable funcion.
    void UpdateNeighborRoutingTable(){
        uint16_t size, i;
        route neighborRoutes[20]; //maximum number of neighbors 20??
        neighbors = call NeighborDiscovery.getNeighbors();
        size = sizeof(neighbors)/ sizeof(neighbors[0]);
        for (i = 0; i < size; i++){
            //use a Temporary route to insert neighbor info into routing table
            neighborRoutes[i].Destination = neighbors[i];
            neighborRoutes[i].NextHop = neighbors[i];
            neighborRoutes[i].Cost = 1; /* distance metric */ //temprarily for NumOfHops
            neighborRoutes[i].TTL = MAX_TTLroute;
        }
        updateRoutingTable(neighborRoutes, i);

    }


    /*
    The procedure updateRoutingTable is the main routine that calls mergeRoute
    to incorporate all the routes contained in a routing update that is received
    from a neighboring node. */
 
    void updateRoutingTable(route * newRoutes, uint16_t size)
    {
        int i;
        for (i = 0; i < size; ++i)
        {
            mergeRoute(&newRoutes[i]);
        }
    }



/*
The routine that updates the local node’s routing table based on a new route is given by mergeRoute. 
Although not shown, a timer function periodically scans the list of routes in the node’s routing table,
decrements the TTL (time to live) field of each route, and discards any routes that have a time to live of 0. 
Notice, however, that the TTL field is reset to MAX TTL any time the route is reconfirmed by an update message 
from a neighboring node.
*/
    void
        mergeRoute(route * newRoute) {
        int i;
        for (i = 0; i <= call Routes.size(); i++)
        {
            if (newRoute->Destination == (call Routes.get(i)).Destination)
            {
                if (newRoute->Cost + 1 < (call Routes.get(i)).Cost)
                {
                    /* found a better route: */
                    break;
                }
                else if (newRoute->NextHop == (call Routes.get(i)).NextHop)
                {
                    /* metric for current next-hop may have changed: */
                    break;
                }
                else
                {
                    /* route is uninteresting---just ignore it */
                    return;
                }
            }
        }
        if (i == call Routes.size())
        {
            /* this is a completely new route; is there room for it? */
            if (i >= MAX_ROUTES)
                return; /* can't fit this route in table so give up */
        }
        newRoute->TTL = MAX_TTLroute; ///Do we want to update the TTL to MAX_TTL every time we get an update
        newRoute->Cost = newRoute->Cost + 1; /* account for hop to get to next node */ 
        call Routes.pushback(*newRoute);
        /* reset TTL */
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

}