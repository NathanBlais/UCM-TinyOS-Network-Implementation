//Author:Nathan Blais

#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/am_types.h"
#include "../../includes/command.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/socket.h"
#include "Timer.h"




module ChatAppP{
  provides interface ChatApp;

  uses interface Transport;

  uses interface List<chatUser> as UserList;


 // uses interface Hashmap<socket_store_t> as Connections; // hash table: list of connections

//  uses interface LocalTime<TMilli>;
//  uses interface Timer<TMilli> as Timer;

//   uses interface List<sendTCPInf> as SendBuff;
//   uses interface List<sendTCPInf> as ReSendBuff;

//   uses interface Queue<pack*>;
//   uses interface Pool<pack>;
//   uses interface Queue<sendTCPInfo*> as SendQueue;
//   uses interface Pool<sendTCPInfo> as SendPool;


}

  /* --------- Questions Area --------- *\
✱This is where we put our general questions
        ➤•⦿◆ →←↑↓↔︎↕︎↘︎⤵︎⤷⤴︎↳↖︎⤶↲↱⤻

    ➤ 
        •
    
    ➤ 
        •
        •

    ➤

    ➤


\* --------- Questions Area --------- */

 //need a send_to_buffer
 //need a send_out


implementation{  

    command void ChatApp.SetupServer(){
        socket_addr_t myAddr; //not realy needed exept to satisfy bind requirements
        socket_t mySocket = call Transport.socket(1); //change to 41

        if (mySocket != 1){
            dbg(TRANSPORT_CHANNEL, "Could not retrive an available socket\n");
            //return;
            }

        myAddr.addr = TOS_NODE_ID; //filled with usless info
        myAddr.port = mySocket;    //filled with usless info

        if(call Transport.bind(mySocket, &myAddr))
            return;

        if(call Transport.listen(mySocket))
            return;

    }

    command void ChatApp.ClientCommand(uint8_t *payload){

    }

}