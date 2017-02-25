#if WIN32
#ifndef _WIN32_WINNT
#  define _WIN32_WINNT 0x501
#endif
#include <winsock2.h>
#include <ws2tcpip.h>
#else
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netdb.h>
#endif
#include <stdio.h>
#include <string.h> 
#include <unistd.h> 
#include <stdlib.h>

#if WIN32
const char *inet_ntop(int af, const void *src, char *dst, socklen_t size)
{
  struct sockaddr_storage ss;
  unsigned long s = size;

  ZeroMemory(&ss, sizeof(ss));
  ss.ss_family = af;

  switch(af) {
    case AF_INET:
      ((struct sockaddr_in *)&ss)->sin_addr = *(struct in_addr *)src;
      break;
    case AF_INET6:
      ((struct sockaddr_in6 *)&ss)->sin6_addr = *(struct in6_addr *)src;
      break;
    default:
      return NULL;
  }
  /* cannot direclty use &size because of strict aliasing rules */
  return (WSAAddressToString((struct sockaddr *)&ss, sizeof(ss), NULL, dst, &s) == 0)?
          dst : NULL;
}
#endif

int32_t ResolveAddress_IPv6(const char *host, char *remote_address);

int32_t ResolveAddress_IPv6(const char *host, char *remote_address)
{
	struct 		addrinfo *result;
	struct 		addrinfo hints;
	int 		error;		
	char		*ptr_address;

	ptr_address = remote_address + 1;

	// Let's get the Ipv6 address if it exists
	memset (&hints, 0, sizeof(hints));

	hints.ai_family = AF_INET6; 		
	hints.ai_socktype = SOCK_STREAM;

	error = getaddrinfo(&host[1], 0, &hints, &result);

	if (error == 0) {
		inet_ntop(AF_INET6, &(((struct sockaddr_in6 *)(result->ai_addr))->sin6_addr), ptr_address, INET6_ADDRSTRLEN);
		*remote_address = (char) strlen(ptr_address);
		freeaddrinfo(result);
		return AF_INET6;
	}

	// Nope, Let us check for an ipv4 address

	memset (&hints, 0, sizeof(hints));

	hints.ai_family = AF_INET; 		
	hints.ai_socktype = SOCK_STREAM;

	error = getaddrinfo(&host[1], 0, &hints, &result);

	if (error == 0) {
   		inet_ntop(AF_INET, &(((struct sockaddr_in *)(result->ai_addr))->sin_addr), ptr_address, INET6_ADDRSTRLEN);
		*remote_address = (char) strlen(ptr_address);
		freeaddrinfo(result);
		return AF_INET;
	}

	remote_address = 0;
	return 0;
}

