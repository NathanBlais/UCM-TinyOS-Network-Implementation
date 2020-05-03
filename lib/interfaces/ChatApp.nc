

interface ChatApp{
    command void SetupServer();
    command void ClientCommand(uint8_t *payload);
}