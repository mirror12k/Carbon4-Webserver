package Carbon4::HTTP::GraphiteServer;
use parent 'Carbon4::HTTP::FileServer';
use strict;
use warnings;

use feature 'say';
use File::Slurper 'read_binary';

use Carbon4::HTTP::MIME;
use Carbon4::HTTP::Response;
use Carbon4::URI;



sub new {
	my ($class, %args) = @_;
	my $self = $class->SUPER::new;

	$self->{execute_extension} = $args{execute_extension} // ".am";

	return $self;
}



sub load_static_file {
	my ($self, $filepath) = @_;

	if ($self->{execute_extension} eq substr $filepath, -length $self->{execute_extension}) {
		# say "executable file: $filepath";

		$self->{response} = Carbon4::HTTP::Response->new('200');
		$self->{response}->header('content-type' => 'text/html');
		$self->{response}->content('');

		eval { $self->run_file($filepath); };

		if ($@) {
			say "server error: $@";
			my $res = Carbon4::HTTP::Response->new;
			$res->code('500');
			$res->content('Server Error');
			$res->header('content-type' => 'text/plain');
			$res->header('content-length' => length $res->content);
			return $res;
		}

		$self->{response}->header('content-length' => length $self->{response}->content) unless defined $self->{response}->header('content-length');

		return $self->{response};

	} else {
		return $self->SUPER::load_static_file($filepath);
	}
}

sub compile_file {
	my ($self, $filepath) = @_;

	my $code = read_binary $filepath;

	if ($code =~ /<\?perl/) {
		$code =~ s/\A(.*?)<\?perl/$self->escape_text($1)/sex;
		$code =~ s/\?>(.*?)(<\?perl|\Z(?!\s))/$self->escape_text($1)/segx;
	} else {
		$code = $self->escape_text($code);
	}

	$code = "sub { my (\$srv, \$req, \$res) = \@_; $code }";
	# say "code: $code";

	my $sub = eval $code;
	die "error compiling '$filepath': $@" if $@;

	return $sub;
}

sub escape_text {
	my ($self, $text) = @_;
	$text =~ s/\\/\\\\/g;
	$text =~ s/'/\\'/g;
	return "\n;\$srv->echo('$text');\n";
}

sub run_file {
	my ($self, $filepath) = @_;
	my $sub = $self->compile_file($filepath);
	return $sub->($self, $self->{request}, $self->{response});
}

sub echo {
	my ($self, @text) = @_;
	$self->{response}->content($self->{response}->content . join '', @text);
}

1;
