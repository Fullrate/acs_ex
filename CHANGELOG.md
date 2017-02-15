0.2.18  Minor bug fix - the session_filter need only the inform data hd(:entries) not the complete envelope as param 2

0.2.17  The session_filter method needs the inform aswell, because it might need to inspect
        further into the inform parameters in order to auth a device. Specifically in case
        of "TR-330" devices who operate behind the CWMP device.

0.2.16  Minor bug in the ipv6 thingy, an ipv6 is a tuple of 8 integers.

0.2.15  Fixed the 204 header (end session) header in testcases.
        Introduced a configurable ipv6 listener.

0.2.14  Introduced the 204 header when ending a session. Thanks to softathome.

0.2.6   the cowboy ip is now configurable, so you can specify which ip to listen to.
        or even {0, 0, 0, 0, 0, 0, 0, 0} for all ipv6 and ipv4, for instance.
