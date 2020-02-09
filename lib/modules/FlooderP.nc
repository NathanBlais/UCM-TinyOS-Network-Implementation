#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module FlooderP
{
	//Provides the SimpleSend interface in order to flood packets
	provides interface Flooder;
	//Uses the SimpleSend interface to forward recieved packet as broadcast
	uses interface SimpleSend as Sender;
	//Uses the Receive interface to determine if received packet is meant for me.
	uses interface Receive as Receiver;
	//Uses the Queue interface to determine if packet recieved has been seen before
	uses interface List<pack> as KnownPacketsList;
}

implementation
{
	pack sendPackage;

	// Prototypes
	void makePack(pack * Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t seq, uint16_t protocol, uint8_t * payload, uint8_t length);
	bool isInList(pack packet);
	error_t addToList(pack packet);

	//Broadcast packet
	command error_t Flooder.send(pack msg, uint16_t dest)
	{
		//Attempt to send the packet
		dbg(FLOODING_CHANNEL, "Sending from Flooder\n");

		if (call Sender.send(msg, AM_BROADCAST_ADDR) == SUCCESS)
		{
			return SUCCESS;
		}
		return FAIL;
	}

	//Event signaled when a node recieves a packet
	event message_t *Receiver.receive(message_t * msg, void *payload, uint8_t len)
	{
		dbg(FLOODING_CHANNEL, "Packet Received in Flooder\n");
		if (len == sizeof(pack))
		{
			pack *contents = (pack *)payload;

			//If I am the original sender or have seen the packet before, drop it
			if ((contents->src == TOS_NODE_ID) || isInList(*contents))
			{
				dbg(FLOODING_CHANNEL, "Dropping packet.\n");
				return msg;
			}
			//Kill the packet if TTL is 0
			if (contents->TTL == 0){
            //do nothing
            dbg(FLOODING_CHANNEL, "TTL: %d\n", contents-> TTL);
            return msg;
            }
			
			dbg(FLOODING_CHANNEL, "Packet has not been seen before, adding it to List\n");
			addToList(*contents);
			if (contents->dest == TOS_NODE_ID)
			{ //if the packet is meant for the current node
				if (PROTOCOL_PING == contents->protocol)
				{
					dbg(GENERAL_CHANNEL, "Ping Message:%s\n", contents->payload);
					makePack(&sendPackage, TOS_NODE_ID, contents->src, MAX_TTL, contents->seq, PROTOCOL_PINGREPLY, (uint8_t *)contents->payload, PACKET_MAX_PAYLOAD_SIZE);
					dbg(GENERAL_CHANNEL, "Sending Ping Reply to %d\n", contents->src);
					call Sender.send(sendPackage, AM_BROADCAST_ADDR);
				}
				else if (PROTOCOL_PINGREPLY == contents->protocol)
				{
					dbg(GENERAL_CHANNEL, "Ping Reply Recived from %d\n", contents->src);
					dbg(GENERAL_CHANNEL, "Package Payload: %s\n", contents->payload);
				}
				else
				{
					dbg(GENERAL_CHANNEL, "temp output statment\n");
				}
			}
			else
			{//the packet is not meant for the current node
				contents-> TTL = (contents->TTL) - 1; //Reduce TTL
				if (PROTOCOL_PING == contents->protocol)
				{
					dbg(FLOODING_CHANNEL, "Flooding Ping\n");
					call Sender.send(*contents, AM_BROADCAST_ADDR);
				}
				else if (PROTOCOL_PINGREPLY == contents->protocol)
				{
					dbg(FLOODING_CHANNEL, "Flooding Ping Reply\n");
					call Sender.send(*contents, AM_BROADCAST_ADDR);
				}
				else
				{
					dbg(FLOODING_CHANNEL, "temp output statment\n");
				}
			}
			return msg;
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
}