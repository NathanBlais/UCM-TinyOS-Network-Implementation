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
		uint8_t id;
		bool flag;
        //maybe add other values here
}neighbor;

typedef struct route
    {
        uint16_t Destination; /* address of destination */
        uint16_t NextHop;     /* address of next hop */
        uint8_t Cost;             /* distance metric */ //temprarily for NumOfHops
        //add other values to determin 
        uint16_t TTL;          /* time to live */
    } route;

#endif /* PACK_BUFFER_H */
