/*
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
 
 See the GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 
 */
//
//  net_udp_iphone.m
//  iPhone Quake
//
//  Kevin Arunski, October 2008
//
#include "quakedef.h"
#include "net_udp.h"

#include <unistd.h>
#include <netdb.h>
#include <net/if.h>
#include <ifaddrs.h>

static unsigned long myAddr = 0;
static int net_controlsocket;
static struct qsockaddr broadcastaddr;

int UDP_Init (void)
{
	char	buff[255];
	struct qsockaddr addr;
	char *colon;
	
	if (COM_CheckParm ("-noudp"))
		return -1;

	struct ifaddrs * myAddresses;
	if (getifaddrs(&myAddresses) == 0)
	{
		struct ifaddrs * ifaddr_entry = myAddresses;
		while (ifaddr_entry != NULL && myAddr == 0)
		{
			// use inet address for "en0" -> should be local WiFi?
			if (ifaddr_entry->ifa_addr->sa_family == AF_INET &&  // it's an inet addr
				strcmp(ifaddr_entry->ifa_name, "en0") == 0 && // and it's ethernet
				ifaddr_entry->ifa_flags & IFF_UP) // and it's up
			{
				struct sockaddr_in * inetAddress = (struct sockaddr_in *)ifaddr_entry->ifa_addr;
				myAddr = inetAddress->sin_addr.s_addr;
			}
			ifaddr_entry = ifaddr_entry->ifa_next;
		}
		
		freeifaddrs(myAddresses);
	}
	
	gethostname(buff, sizeof(buff));
	
	// if the quake hostname isn't set, set it to the machine name
	if (Q_strcmp(hostname.string, "UNNAMED") == 0)
	{
		buff[15] = 0;
		Cvar_Set ("hostname", buff);
	}
	
	if ((net_controlsocket = UDP_OpenSocket (0)) == -1)
		Sys_Error("UDP_Init: Unable to open control socket\n");
	
	((struct sockaddr_in *)&broadcastaddr)->sin_family = AF_INET;
	((struct sockaddr_in *)&broadcastaddr)->sin_addr.s_addr = INADDR_BROADCAST;
	((struct sockaddr_in *)&broadcastaddr)->sin_port = htons(net_hostport);
	
	UDP_GetSocketAddr (net_controlsocket, &addr);
	Q_strcpy(my_tcpip_address,  UDP_AddrToString (&addr));
	colon = Q_strrchr (my_tcpip_address, ':');
	if (colon)
		*colon = 0;
	
	Con_Printf("UDP Initialized\n");
		tcpipAvailable = true;
	return net_controlsocket;
}

unsigned long UDP_GetMyAddr()
{
	return myAddr;
}

int UDP_GetControlSocket()
{
	return net_controlsocket;
}

const struct qsockaddr * UDP_GetBroadcastAddr()
{
	return &broadcastaddr;
}
