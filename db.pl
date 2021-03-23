#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';

use Carbon4::Server;
use Carbon4::TCPReceiver;
use Carbon4::Limestone::JSONPacketConnection;
use Carbon4::Limestone::LimestoneDatabase;



my $srv = Carbon4::Server->new(
	debug => 1,
	receivers => [ Carbon4::TCPReceiver->new(2047, 'Carbon4::Limestone::JSONPacketConnection', {
		callback => Carbon4::Limestone::LimestoneDatabase->new->serve_database('db'),
	}) ],
)->start;





