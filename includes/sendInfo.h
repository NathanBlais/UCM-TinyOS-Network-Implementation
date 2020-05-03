//Author: UCM ANDES Lab
//Date: 2/15/2012
#ifndef PACK_BUFFER_H
#define PACK_BUFFER_H

#include "packet.h"
#include "socket.h"

enum{
	SEND_BUFFER_SIZE=128,
	MAX_USER_NAME_LEN=10
};

typedef struct sendInfo{
	pack packet;
	uint16_t src;
	uint16_t dest;
}sendInfo;

typedef struct reciveInfo{
	message_t msg;
	pack payload;
	uint8_t len;
}reciveInfo;

typedef struct sendTCPInfo{
	socket_t socKey;
	uint8_t flag;
	uint8_t seq;
	uint8_t ack;
	pack payload;
	uint8_t length;
}sendTCPInfo;

typedef struct rsendTCPInfo{
	socket_t socKey;
	uint8_t flag;
	pack payload;
	uint8_t length;
}rsendTCPInfo;

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

typedef struct chatUser{
		char name[MAX_USER_NAME_LEN];
		uint8_t UsersPort;

}chatUser;


#endif /* PACK_BUFFER_H */
