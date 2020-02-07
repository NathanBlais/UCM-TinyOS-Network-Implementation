module FloodC(){
    provides {
        //Provides the SimpleSend interface in order to flood packets
        interface SimpleSend as Flooder;
    }
    uses {
        //Uses the SimpleSend interface to forward recieved packet as broadcast
	    interface SimpleSend as Sender;
	    //Uses the Receive interface to determine if received packet is meant for me.
	    interface Receive as Receiver;
	    ////Uses the Queue interface to determine if packet recieved has been seen before
	    //interface List<pack> as KnownList;
    }
}

implementation {






    
}