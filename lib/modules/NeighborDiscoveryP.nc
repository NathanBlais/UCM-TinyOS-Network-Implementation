//Author:Nathan Blais
#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

#define MAX_NEIGHBORS 20


module NeighborDiscoveryP
{
    provides interface NeighborDiscovery;
    //Uses SimpleSend interface to forward recieved packet as broadcast
    uses interface SimpleSend as Sender;
    //Uses the Receive interface to determine if received packet is meant for me.
    uses interface Receive as Receiver;
    uses interface AMPacket;
    //Uses the Queue interface to determine if packet recieved has been seen before
    uses interface List<neighbor> as Neighborhood;
    uses interface Timer<TMilli> as periodicTimer;
}

implementation
{
	// Globals
    pack sendPackage;
    neighbor neighborHolder;
    uint16_t neighbors[MAX_NEIGHBORS];
    uint16_t SEQ_NUM = 1;
    uint8_t tmp = 8; //put in to avoid warning
    uint8_t *temp = &tmp;
    


    // Prototypes
    void makePack(pack * Package, uint16_t src, uint16_t dest,
                    uint16_t TTL, uint16_t seq, uint16_t protocol,
                    uint8_t * payload, uint8_t length);
    bool isNeighbor(uint16_t nodeid);
    error_t addNeighbor(uint16_t nodeid);
    void updateNeighbors();
    void printNeighborhood();

    command void NeighborDiscovery.run()
    {
        makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 1, SEQ_NUM, PROTOCOL_PING, temp, PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);

        call periodicTimer.startPeriodic(20000);
    }

    task void updateNeighborsTask(){
        updateNeighbors();
    }

    task void senderTask(){
        makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 1, SEQ_NUM, PROTOCOL_PING, temp, PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
    }


    event void periodicTimer.fired()
    {
        dbg(NEIGHBOR_CHANNEL, "Sending from NeighborDiscovery\n");
        post updateNeighborsTask();

        //optional - call a function to organize the list
        post senderTask();
    }

    

    command void NeighborDiscovery.print()
    {
        printNeighborhood();
    }

    event message_t *Receiver.receive(message_t * msg, void *payload, uint8_t len)
    {
        if (len == sizeof(pack)) //check if there's an actual packet
        {
            pack *contents = (pack *)payload;
            dbg(NEIGHBOR_CHANNEL, "NeighborReciver Called \n");

            if (PROTOCOL_PING == contents->protocol)
            {
                contents->src = TOS_NODE_ID;
                contents->dest = call AMPacket.source(msg);
                contents->TTL = (contents->TTL) - 1;
                contents->protocol = PROTOCOL_PINGREPLY;

                dbg(NEIGHBOR_CHANNEL, "Sending Neighbor Reply\n");
                call Sender.send(*contents, contents->dest);
                return msg;
            }

            else if (PROTOCOL_PINGREPLY == contents->protocol) //we made replies be of one
            {
                if (isNeighbor(contents->src) == TRUE)
                {
                    int i;
                    uint16_t size = call Neighborhood.size();

                    for (i = 0; i < size; i++){ //update neighbor values
                        if (contents->src == (call Neighborhood.get(i)).id){
                            neighbor *nodes = call Neighborhood.getPointer();
                            nodes[i].flag = FALSE;
                            return msg;
                        }
                    }
                }
                else
                {
                    addNeighbor(contents->src);
                }
            }
            else
            {
                dbg(NEIGHBOR_CHANNEL, "Unknown Protocal %d\n", len);
                return msg;
            }
        }
        dbg(NEIGHBOR_CHANNEL, "Unknown Packet Type %d\n", len);
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

    //Function to check if packet matches a packet in Neighborhood
    bool isNeighbor(uint16_t nodeid)
    {
        uint16_t size = call Neighborhood.size();
        uint16_t i;
        neighbor node;
        if (!call Neighborhood.isEmpty())
        {
            for (i = 0; i < size; i++)
            {
                node = call Neighborhood.get(i);
                if (node.id == nodeid)
                    return TRUE;
            }
        }
        return FALSE;
    }

    //Function to add packet to Neighborhood. If the list is full the last element is
    //removed and the new packet added. Does not check if a packet is already in the list.
    error_t addNeighbor(uint16_t nodeid) //might want to implement this diffrently
    {
        //uint16_t size = call Neighborhood.size();
        neighbor node;
        node.id = nodeid;
        node.flag = FALSE;

        if (call Neighborhood.pushback(node) == TRUE)
            return SUCCESS;
        else
        {
            call Neighborhood.popfront();
            if (call Neighborhood.pushback(node) == TRUE)
                return SUCCESS;
            else
                return FAIL;
        }
    }
    void updateNeighbors()
    {
        uint16_t size = call Neighborhood.size();
        uint16_t i;
        neighbor *nodes = call Neighborhood.getPointer();

        if (!call Neighborhood.isEmpty())
        {
            for (i = 0; i < size; i++)
            {
                if (nodes[i].flag == TRUE)
                    call Neighborhood.remove(i);
                else
                    nodes[i].flag = TRUE;
            }
        }
    }

    void printNeighborhood()
    {
        uint16_t size = call Neighborhood.size();
        uint16_t i;
        neighbor node;

        dbg(GENERAL_CHANNEL, "Node %d Neighbor List:\n", TOS_NODE_ID);

        for (i = 0; i < size; i++)
        {
            node = call Neighborhood.get(i);
            dbg(GENERAL_CHANNEL, "\t\tNode: %d Flag: %d\n", node.id, node.flag);
        }
    }

    command uint16_t *NeighborDiscovery.getNeighbors()
    {
        //First zero out neighbors array
        uint16_t i, size = call Neighborhood.size();
        neighbor node;

        for (i = 0; i < size; i++)
            neighbors[i] = 0;

        //Then populate based on NeighborList
        for (i = 0; i < size; i++)
        {
            node = call Neighborhood.get(i);
            neighbors[i] = node.id;
        }
        return neighbors;
    }

    command uint16_t NeighborDiscovery.getNeighborhoodSize(){
        return call Neighborhood.size();
    }

    command neighbor *NeighborDiscovery.getNeighborsPointer(){
        return call Neighborhood.getPointer();
    }


}//for implementation