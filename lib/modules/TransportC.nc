//      Author:Nathan Blais
//Date Created:2020-03-21

configuration TransportC{
	provides interface Transport;
}

implementation {
	components TransportP;	
	Transport = TransportP.Transport;
	
	//Wire the SimpleSend interface used by TransportP to the one provided by SimpleSendC
	components new SimpleSendC(AM_TCP) as Sender;
	TransportP.Sender -> Sender;
	
	//Wire the Receive interface used by TransportP to the one provided by AMReceiverC()
	components new AMReceiverC(AM_TCP) as Receiver;
	TransportP.Receiver -> Receiver;
    TransportP.AMPacket -> Receiver;

	////Wire the List interface used by TransportP to the one provided by ListC()
    //components new ListC(pack, 20) as KnownPacketsList;
    //TransportP.KnownPacketsList -> KnownPacketsList;

	//Wire the DistanceVectorRouting interface used by TransportP to the one provided by DistanceVectorRoutingC()
    components  DistanceVectorRoutingC;
    Node.DistanceVectorRouting ->  DistanceVectorRoutingC; 

    //NOTE: wire timmers 
}