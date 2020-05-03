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

    }

    command void ChatApp.ClientCommand(uint8_t *payload){

            char * convertToString = (char *) payload;
            //char * token = strtok (convertToString,"\r\n");
            char * commandType = strtok(convertToString, " ");
            char * userName;
            char * clientPort;
            char * message;
            uint8_t port;
            uint8_t * covertBackFromStringM;
            uint8_t *covertBackFromStringUN;
            char hello[] = "hello" ;
            char msg[] = "msg";
            char whisper[] = "whisper";
            char listusr [] = "listusr";

            if (strcmp(commandType, hello) == 0)
            {
                dbg(APPLICATION_CHANNEL,"hello command\n");
                //hello [username] [clientport]\r\n
                //make it call the hello 
                userName = strtok (NULL," ");
                
                clientPort = strtok (NULL,"\r\n");
                covertBackFromStringUN = (uint8_t *) userName;
                port = atoi(clientPort);
                dbg (APPLICATION_CHANNEL,"userName : %s\n clientPort:%d \n", userName, port);

                 //make it call the hello function
                
            }
            else if (strcmp(commandType, msg) == 0)
            {
                dbg(APPLICATION_CHANNEL,"msg command\n");\
                //msg [message]\r\n
                message = strtok (NULL,"\r\n");
                covertBackFromStringM = (uint8_t*) message;
                dbg (APPLICATION_CHANNEL, "message is:%s \n", covertBackFromStringM);

                //call msg/whisper function
            }
            else if (strcmp(commandType, whisper) == 0)
            {
                dbg(APPLICATION_CHANNEL,"whisper command\n");
                //whisper [username] [message]\r\n
                userName = strtok (NULL," ");
                message = strtok (NULL,"\r\n");
                covertBackFromStringUN = (uint8_t*) userName;
                covertBackFromStringM = (uint8_t*) message;
                //call whisper/msg function
                dbg (APPLICATION_CHANNEL, "username is:%s \n", covertBackFromStringUN);
                dbg (APPLICATION_CHANNEL, "message is:%s \n", covertBackFromStringM);
            }
           
            else 
            {
                commandType = strtok(commandType, "\r\n");

                if (strcmp(commandType, listusr) == 0)
                    {
                    dbg(APPLICATION_CHANNEL,"listusr command\n");
                        //call listusr function
                    }
                else
                {
                dbg(APPLICATION_CHANNEL,"unrecognized command %s\n", commandType);
                }
            }


    }

}