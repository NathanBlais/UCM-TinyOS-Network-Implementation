/**
* CSE 160 - University of California, Merced
*
* @author Nathan Blais
* @date   2020/02/06
*
**/

#include "../../includes/am_types.h"

configuration FloodConfig{
	//Provides the SimpleSend interface in order to flood
	provides interface SimpleSend as Flooder;
}

implementation {
	//Export the implemention of SimpleSend.send() to FloodC
	components FloodC;	
	Flooder = FloodC.Flooder;
	
	//Wire the SimpleSend interface used by FloodC to the one provided by SimpleSendC
	components new SimpleSendC(AM_FLOODING) as Sender;
	FloodC.Sender -> Sender;
	
	//Wire the Receive interface used by FloodC to the one provided by AMReceiverC()
	components new AMReceiverC(AM_FLOODING) as Receiver;
	FloodC.Receiver -> Receiver;
	
	////Wire the List interface used by FloodC to the one provided by ListC()??
    //components new ListC(pack, 20) as KnownList;
    //FloodC.KnownList -> KnownList;
}