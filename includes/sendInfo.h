//Author: UCM ANDES Lab
//Date: 2/15/2012
#ifndef PACK_BUFFER_H
#define PACK_BUFFER_H

#include "packet.h"

enum{
	SEND_BUFFER_SIZE=128
};

typedef struct sendInfo{
	pack packet;
	uint16_t src;
	uint16_t dest;
}sendInfo;

typedef struct neighbor {
		uint16_t id;
		bool flag;
//store a RTT here
}neighbor;

typedef struct route{
        neighbor Destination; /* address of destination */
        neighbor NextHop;     /* address of next hop */
        uint8_t Cost;             /* distance metric */ //temprarily for NumOfHops

        //add other values to determin 
        uint16_t TTL;          /* time to live */
}route;

typedef struct tcpHeader{
	uint8_t Src_Port;
	uint8_t Dest_Port;
	uint8_t Seq_Num;		//Sequence Number	- which byte chunk is being sent
	uint8_t Acknowledgment;		//ACK - next byte expected (seq + 1)
	//uint8_t Len; 				//Data Offset
	unsigned int Flags: 3;
	uint8_t Advertised_Window;	// buffer size
	//uint8_t Checksum; //optional
	//uint8_t UrgPtr; //optional
	//DATA <- NEED TO IMPLEMENT THIS

}tcpHeader;

//Flags for TCP
#define URG 0  //signifies that this segment contains urgent data.
#define ACK 1  //is set any time the Acknowledgment field is valid, implying that the receiver should pay attention to it.
#define PUSH 2 //signifies that the sender invoked the push operation, which indicates to the receiving side of TCP that it should notify the receiving process of this fact.
#define RESET 3 //signifies that the receiver has become confused—for example, because it received a segment it did not expect to receive—and so wants to abort the connection.
#define SYN 4  //-never carries payload data
#define FIN 5  //-never carries payload data



#endif /* PACK_BUFFER_H */
