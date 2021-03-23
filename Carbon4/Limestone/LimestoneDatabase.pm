package Carbon4::Limestone::LimestoneDatabase;
use strict;
use warnings;

use feature 'say';

use JSON;



sub new {
	my ($class, %args) = @_;
	my $self = bless {}, $class;

	$self->{collections} = {};

	return $self;
}

sub serve_database {
	my ($self, $path, %opts) = @_;

	mkdir $path;
	
	return sub {
		my ($req) = @_;

		my $res = eval {
			return $self->process_request($req, $path);
		};

		return { success => 0, error => $@ } if $@;
		return $res;
	};
}

sub process_request {
	my ($self, $req, $path) = @_;

	if ($req->{type} eq 'get') {
		my $data = $self->read_collection("$path/$req->{collection}.json");
		return { success => 1, data => $data };
	} elsif ($req->{type} eq 'insert') {
		my $id = $self->insert_collection("$path/$req->{collection}.json", $req->{data});
		return { success => 1, insert_id => $id };
	} else {
		return { success => 0, error => 'invalid type' };
	}
}

sub read_collection {
	my ($self, $fullpath) = @_;

	return [] unless -e $fullpath;
	my $f = IO::File->new($fullpath, 'r');
	my $len = -s $f;
	$f->read(my $buf, $len);
	$f->close;

	return decode_json($buf);
}

sub write_collection {
	my ($self, $fullpath, $data) = @_;

	my $f = IO::File->new("${fullpath}_newer", 'w');
	$f->print(encode_json($data));
	rename "${fullpath}_newer", "$fullpath";
}

sub insert_collection {
	my ($self, $fullpath, $entries) = @_;

	my $collection = $self->read_collection($fullpath);
	push @$collection, @$entries;
	$self->write_collection($fullpath, $collection);

	return @$collection;
}


1;


