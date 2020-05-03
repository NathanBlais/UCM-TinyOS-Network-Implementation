#ANDES Lab - University of California, Merced
#Author: UCM ANDES Lab
#$Author: abeltran2 $
#$LastChangedDate: 2014-08-31 16:06:26 -0700 (Sun, 31 Aug 2014) $
#! /usr/bin/python
import sys
from TOSSIM import *
from CommandMsg import *

class TestSim:
    moteids=[]
    # COMMAND TYPES
    CMD_PING = 0
    CMD_NEIGHBOR_DUMP = 1
    CMD_LINKSTATE_DUMP = 2
    CMD_ROUTE_DUMP = 3
    CMD_TEST_CLIENT = 4
    CMD_TEST_SERVER = 5
    CMD_KILL = 6
    CMD_CLIENT_CLOSE = 7
    CMD_SERVER_READ = 15
    CMD_CHAT_SERVER_SET = 16
    CMD_CHAT_CLIENT_CMD = 17
    CMD_ERROR = 10

    # CHANNELS - see includes/channels.h
    COMMAND_CHANNEL="command";
    GENERAL_CHANNEL="general";

    # Project 1
    NEIGHBOR_CHANNEL="neighbor";
    FLOODING_CHANNEL="flooding";

    # Project 2
    ROUTING_CHANNEL="routing";

    # Project 3
    TRANSPORT_CHANNEL="transport";

    # Project 4
    APPLICATION_CHANNEL="application";

    # Personal Debuggin Channels for some of the additional models implemented.
    HASHMAP_CHANNEL="hashmap";

    # Initialize Vars
    numMote=0

    def __init__(self):
        self.t = Tossim([])
        self.r = self.t.radio()

        #Create a Command Packet
        self.msg = CommandMsg()
        self.pkt = self.t.newPacket()
        self.pkt.setType(self.msg.get_amType())

    # Load a topo file and use it.
    def loadTopo(self, topoFile):
        print 'Creating Topo!'
        # Read topology file.
        topoFile = 'topo/'+topoFile
        f = open(topoFile, "r")
        self.numMote = int(f.readline());
        print 'Number of Motes', self.numMote
        for line in f:
            s = line.split()
            if s:
                print " ", s[0], " ", s[1], " ", s[2];
                self.r.add(int(s[0]), int(s[1]), float(s[2]))
                if not int(s[0]) in self.moteids:
                    self.moteids=self.moteids+[int(s[0])]
                if not int(s[1]) in self.moteids:
                    self.moteids=self.moteids+[int(s[1])]

    # Load a noise file and apply it.
    def loadNoise(self, noiseFile):
        if self.numMote == 0:
            print "Create a topo first"
            return;

        # Get and Create a Noise Model
        noiseFile = 'noise/'+noiseFile;
        noise = open(noiseFile, "r")
        for line in noise:
            str1 = line.strip()
            if str1:
                val = int(str1)
            for i in self.moteids:
                self.t.getNode(i).addNoiseTraceReading(val)

        for i in self.moteids:
            print "Creating noise model for ",i;
            self.t.getNode(i).createNoiseModel()

    def bootNode(self, nodeID):
        if self.numMote == 0:
            print "Create a topo first"
            return;
        self.t.getNode(nodeID).bootAtTime(1333*nodeID);

    def bootAll(self):
        i=0;
        for i in self.moteids:
            self.bootNode(i);

    def moteOff(self, nodeID):
        self.t.getNode(nodeID).turnOff();

    def moteOn(self, nodeID):
        self.t.getNode(nodeID).turnOn();

    def run(self, ticks):
        for i in range(ticks):
            self.t.runNextEvent()

    # Rough run time. tickPerSecond does not work.
    def runTime(self, amount):
        self.run(amount*1000)

    # Generic Command
    def sendCMD(self, ID, dest, payloadStr):
        self.msg.set_dest(dest);
        self.msg.set_id(ID);
        self.msg.setString_payload(payloadStr)

        self.pkt.setData(self.msg.data)
        self.pkt.setDestination(dest)
        self.pkt.deliver(dest, self.t.time()+5)

    def ping(self, source, dest, msg):
        self.sendCMD(self.CMD_PING, source, "{0}{1}".format(chr(dest),msg));

    def neighborDMP(self, destination):
        self.sendCMD(self.CMD_NEIGHBOR_DUMP, destination, "neighbor command");

    def routeDMP(self, destination):
        self.sendCMD(self.CMD_ROUTE_DUMP, destination, "routing command");

    def addChannel(self, channelName, out=sys.stdout):
        print 'Adding Channel', channelName;
        self.t.addChannel(channelName, out);

    # Added Generic Command
    def cmdTestServer(self, address, port):
        print 'Listening for Server connections..', address, port;
        self.sendCMD(self.CMD_TEST_SERVER, address, chr(port));

    def cmdTestClient(self, address, sourcePort, dest, destPort, msg):
        print '\t\tNode',address,':',sourcePort,'wants to connect to',dest,':',destPort;
        self.sendCMD(self.CMD_TEST_CLIENT, address, "{0}{1}{2}{3}".format(chr(sourcePort), chr(dest), chr(destPort), msg));
                            #[selfAdress] [srcPort] [dest] [destPort] [transfer]

    def cmdClientClose(self, address, sourcePort, dest, destPort):
        print 'Client:',address,'Port:',sourcePort,'wants to close Server/Port:' , dest, destPort;
        self.sendCMD(self.CMD_CLIENT_CLOSE, address, "{0}{1}{2}{3}".format(chr(address), chr(sourcePort), chr(dest), chr(destPort)));
                            #[client adress] [srcPort] [dest] [destPort]

    def cmdServerRead(self, address, port, bufflen):
        print 'Server Calling Read for', address, port;
        self.sendCMD(self.CMD_SERVER_READ, address, "{0}{1}".format(chr(port), chr(bufflen)));

    def cmdChatServerSet(self, address):
        self.sendCMD(self.CMD_CHAT_SERVER_SET, address, "chat command");

    def cmdChatClientCmd(self, address, msg):
        self.sendCMD(self.CMD_CHAT_CLIENT_CMD, address, msg);

def main():
    s = TestSim();
    s.runTime(10);
    #s.loadTopo("example.topo");
    s.loadTopo("long_line.topo");
    #s.loadTopo("Project2Topo.topo");
    s.loadNoise("no_noise.txt");
    #s.loadNoise("meyer-heavy.txt");
    #s.loadNoise("some_noise.txt");
    s.bootAll();
    #General
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    #Project 1
    #s.addChannel(s.FLOODING_CHANNEL);
    #s.addChannel(s.NEIGHBOR_CHANNEL); 
    #Project 2
    #s.addChannel(s.ROUTING_CHANNEL);
    #Project 3
    s.addChannel(s.TRANSPORT_CHANNEL);
    #Possibly add seperate server and client channels

    #Project 4
    s.addChannel(s.APPLICATION_CHANNEL);

#####***DVR TEST***##### 

    s.runTime(1);
    #s.runTime(126); #Fastest time with a "151 | call advertiseTimer.startOneShot(6000);"
    s.runTime(300);
    #for i in range(1, 19):
    #     s.routeDMP(i);
    #     s.runTime(1);
    #s.runTime(10);
    #s.ping(2, 6, "Hi!");
    #s.runTime(100);

#####***TCP Test***##### 
    #s.ping(1, 6, "I'll have you know I gr");
    #s.cmdTestServer(6,10); #[adress] [port]
    s.runTime(40); #no noise 100, some noise 100
    # s.ping(1, 6, "I'll have you know I gr");
    # s.runTime(10);
    # s.ping(1, 6, "I'll have you know I gr");
    # s.runTime(10);
    # s.ping(1, 6, "I'll have you know I gr");
    # s.cmdTestClient(1,8,6,10, "Hello,_bozo!"); #[selfAdress] [srcPort] [dest] [destPort] [transfer]
    # s.runTime(200);  #no noise 350, some noise 350
    # s.cmdServerRead(6,10,26); #[dest][destPort][length]
    # s.runTime(1);  #no noise 300, some noise 300
    # s.cmdClientClose(1,8,6,10); #[client adress] [srcPort] [dest] [destPort]
    # s.runTime(100); #no noise 200, some noise 200

###***Chat Client and Server Test*** ###
    s.cmdChatServerSet(1);
    s.runTime(1);
    s.cmdChatClientCmd(2, "hello Josseline 2\r\n");
    s.runTime(200);
    s.cmdChatClientCmd(2, "msg Hello Word!\r\n");
    s.runTime(200);
    #s.cmdChatClientCmd(1, "whisper Nathan Hola \r\n");
    s.runTime(1);
    #s.cmdChatClientCmd(1, "listusr \r\n" );
    s.runTime(1);

#####***NEIGHBOR DISCOVERY TEST***##### 
    # s.runTime(50);
    # s.neighborDMP(1);
    # s.runTime(5);
    # s.neighborDMP(2);
    # s.runTime(5);
    # s.neighborDMP(3);
    # s.runTime(5);
    # s.neighborDMP(4);
    # s.runTime(10);



#####***PACKET  FLOODING   TEST***#####
    # s.runTime(20);
    # s.ping(1, 2, "Hello, World");
    # s.runTime(10);
    # s.ping(1, 17, "Hi!");
    # s.runTime(5);
    # s.runTime(1);
    # s.routeDMP(17);
    # s.runTime(100);




if __name__ == '__main__':
    main()


