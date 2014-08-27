Over time I will add my really really old out-of-date sys and network admin perl scripts. I'm putting these here for the multitude of network engineers that ask if they should learn scripting or if there's a script to do some task. Over 8 years, I wrote a script to do just about everything. There are better ways to do things now, but I hope this at least gives people a starting point. Or just ammunition to make fun of me. Either one.

By all means do whatever you want with this code, but I CAN NOT SUPPORT YOU OR BE RESPONSIBLE IF YOU BLOW SOMETHING UP AND TAKE DOWN YOUR NETWORK. Ahem.

Also, I have no idea if these things will even work anymore.

## Script Descriptions

### setPortDescription.pl - Set ethernet interface description dynamically by connected device

This is one of the few scripts that uses SNMP::Info which is what the NetDisco software is built on. I wrote tens of thousands of lines of perl SNMP code before I ever found SNMP::Info and I wish I had found it much sooner. It's done way better than my code. Anyway.

This script takes a list of devices as arguments or pulls them from a database (useless for you). It does two things:

* Looks up the IP last seen on this port and resolves it to a host name and sets that as the port description (useless for you unless you have a backend way to map a port to a MAC address to an IP address. I have other code that does that, but I don't know when I'll get it up here).
* Grabs the CDP neighbor info and sets the port description to the neightbor name. This is probably the only interesting part for you.

Then it saves the config. For now, you can ignore the Chronicle modules since those are my code and they aren't currently available. You'll need the SNMP::Info module.
