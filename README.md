
## Provisioning script that deploys the Sparta tic-tac-toe Node.js app to an Ubuntu EC2 instance

Requirements / assumptions:
- Ubuntu EC2 with passwordless `sudo`
- security group ports 22 and 80 open
- run as a normal user, not with `sudo ./provision-app.sh`

To run:

```linux```
curl -fsSL https://raw.githubusercontent.com/daria-dot/tech613-tictactoe/main/provision-app.sh -o provision-app.sh
chmod +x
./provision-app.sh
``````

then visit http://<public-ip>
