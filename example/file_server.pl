#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';

use Carbon4::Server;
use Carbon4::TCPReceiver;
use Carbon4::HTTP::Connection;
use Carbon4::HTTP::FileServer;



# this creates a fileserver on http://localhost:5001/ which shows pages from this directory
my $srv = Carbon4::Server->new(
	# shows logs for us
	debug => 1,
	# multiple ports can be handled by the same server
	receivers => [
		# tcp or ssl
		Carbon4::TCPReceiver->new(
			# specify our port
			5001,
			# specify that we are accepting http connections on this port
			'Carbon4::HTTP::Connection',
			# arguments to our http connection, specifying a file server to process our requests
			{ callback => Carbon4::HTTP::FileServer->new->route_directory('/', '.') }
		),
	],
)->start;





