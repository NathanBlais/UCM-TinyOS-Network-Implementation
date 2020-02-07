configuration FloodConfig{
	//Provides the SimpleSend interface in order to flood
	provides interface Flooder;
}

implementation {
	//Export the implemention of SimpleSend.send() to FloodC
	components FloodC;	
	Flooder = FloodC.Flooder;
	
	//Wire the SimpleSend interface used by SimpleFloodP to the one provided by SimpleSendC
	components new SimpleSendC(AM_FLOODING) as Sender;
	FloodC.Sender -> Sender;
	
	//Wire the Receive interface used by SimpleFloodP to the one provided by AMReceiverC()
	components new AMReceiverC(AM_FLOODING) as Receiver;
	FloodC.Receiver -> Receiver;
}