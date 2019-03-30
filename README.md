
If, like me, you're amazed by the number of connections made everyday to your
SSH port, do as I did: change the port of your SSH server and run SSHsink.

What it does is really simple: listen to the 22 port, send a welcome message
to its peer and close the connection. The peer IP is added to hash and if it's
the first connection, it will launch its companion app, SSHcounterstrike.

SSHcounterstrike will try to log in the remote machine and execute whatever
you want on it if the login is successful.

Use the sshcounterstrike.yml configuration file to customize the user names,
passwords, ports and commands to execute.

There's a second companion app, sshmsg which sends messages to SSHsink either
to stop it or to save the IPs hash to a file named sshsink.state.json (which
is reloaded when SSHsink is restarted). The message must be passed as the first
argument to sshmsg.

Messages are configured through the sshmsg.msgs.json file. Except for the
welcome message, the key can be anything but the value must be the name of
a method which SSHsink can respond to.

SSHsink only processes messages coming from 127.* or 192.168.*

When sending a 'leave' message to stop SSHsink, it will set a flag to tell
it to exit but as another thread will be listening in the meantime, it will
stop on the next connection, so sending the message twice will finally stop it.

Stopping SSHsink won't stop any running instance(s) of SSHcounterstrike since
they're forked detached. They will stop on their own or you have to kill them
manually.

SSHsink logs everything in the sshsink.log file. SSHcounterstrike also logs
some messages into the SSHsink log but also logs into the sshcounterstrike.log
file (only the final result of the connection attempts) and if a login is
successful, a log file named IP.log is created in the sshcounterstrike.logs
subdirectory, where IP is the incoming IP given by SSHsink, which records the
result of the commands execution.

The provided configuration file for SSHcounterstrike is a sample and needs to
be tweeked if ever you hope a successful counter strike.

SSHsink must be run as root to be granted to listen to the 22 port and from
the directory it resides in.

SSHcounterstrike needs the 'net/ssh' gem (gem install net-ssh)

Have fun!


If you find this kind of language a bit warlike, here are the first entries of
my sshsink.state.json file after running LESS than a month. I have troubles
to believe these guys forgot their passwords and desperatly try to log back
onto their system using a wrong IP...

{
  "xxx.xx.xx.xxx": 79743,
  "xxx.xx.xx.xxx": 49661,
  "xxx.xx.xx.xxx": 28090,
  "xx.xxx.xxx.xxx": 15960,
  "xxx.xx.xx.xxx": 10004,
  "xxx.xx.xx.xxx": 9020,
  "xxx.xx.x.xxx": 8048,
  .
  .
  .
}
