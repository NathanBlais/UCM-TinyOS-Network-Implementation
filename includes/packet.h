//Author: UCM ANDES Lab
//$Author: abeltran2 $
//$LastChangedBy: abeltran2 $

#ifndef PACKET_H
#define PACKET_H


#include "protocol.h"
#include "channels.h"

enum{
	PACKET_HEADER_LENGTH = 8,
	TCP_HEADER_LENGTH = 10,
//	PACKET_HEADER_LENGTH = sizeof(pack),
	PACKET_MAX_PAYLOAD_SIZE = 28 - PACKET_HEADER_LENGTH,
	TCP_PACKET_MAX_PAYLOAD_SIZE = PACKET_MAX_PAYLOAD_SIZE - TCP_HEADER_LENGTH,
	//MAX_TTL = 15
	MAX_TTL = 20

	
};

enum{
 	MAX_ROUTES = 255, /* maximum size of routing table */
	MAX_TTLroute = 128, /* value until route expires */
	MAX_COST = 255
};

typedef nx_struct pack{
	nx_uint16_t src;
	nx_uint16_t dest;
	nx_uint8_t TTL;		//Time to Live
	nx_uint16_t seq;	//Sequence Number
	nx_uint8_t protocol;
	nx_uint8_t payload[PACKET_MAX_PAYLOAD_SIZE];
}pack;

typedef struct tcpHeader{
	uint8_t Src_Port;
	uint8_t Dest_Port;
	uint8_t Seq_Num;		//Sequence Number	- which byte chunk is being sent
	uint8_t Acknowledgment;		//ACK - next byte expected (seq + 1)
	uint8_t Len; 				//Data Offset
	//unsigned int Flags: 3;
	unsigned int Flags: 6;
	uint8_t Advertised_Window;	// buffer size
	//uint8_t Checksum; //optional
	//uint8_t UrgPtr; //optional
	uint8_t payload[TCP_PACKET_MAX_PAYLOAD_SIZE];	// DATA

}tcpHeader;


//Flags for TCP
#define URG 0x1  //signifies that this segment contains urgent data.
#define ACK 0x2  //is set any time the Acknowledgment field is valid, implying that the receiver should pay attention to it.
#define PUSH 0x4 //signifies that the sender invoked the push operation, which indicates to the receiving side of TCP that it should notify the receiving process of this fact.
#define RESET 0x8 //signifies that the receiver has become confused—for example, because it received a segment it did not expect to receive—and so wants to abort the connection.
#define SYN 0x10 //16-never carries payload data
#define FIN 0x20  //32-never carries payload data

// //Flags for TCP
// #define URG 0  //signifies that this segment contains urgent data.
// #define ACK 1  //is set any time the Acknowledgment field is valid, implying that the receiver should pay attention to it.
// #define PUSH 2 //signifies that the sender invoked the push operation, which indicates to the receiving side of TCP that it should notify the receiving process of this fact.
// #define RESET 3 //signifies that the receiver has become confused—for example, because it received a segment it did not expect to receive—and so wants to abort the connection.
// #define SYN 4  //-never carries payload data
// #define FIN 5  //-never carries payload data

/*
 * logPack
 * 	Sends packet information to the general channel.
 * @param:
 * 		pack *input = pack to be printed.
 */
void logPack(pack *input){
	dbg(GENERAL_CHANNEL, "Src: %hhu Dest: %hhu Seq: %hhu TTL: %hhu Protocol:%hhu  Payload: %s\n",
	input->src, input->dest, input->seq, input->TTL, input->protocol, input->payload);
}

enum{
	AM_PACK=6
};

#endif
