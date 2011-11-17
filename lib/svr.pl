# Copyright (C) <2011>  <Scott Smith> <smitherz82@gmail.com>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use IO::Socket;

# Pid storage
our @children;

sub start_daemon_server
{
	my $port = shift;

	close(STDIN);
	close(STDOUT);
	close(STDERR);

	exit if (fork());

	while(1) {
		start_server($port);
	}
}

sub start_server
{
	my $port = shift;

	my $server = new IO::Socket::INET(Proto => 'tcp', LocalPort => $port, Listen => SOMAXCONN, Reuse => 1);

	$server or die "Unable to create server socket: $!" ;

	while (my $client = $server->accept()) {
		$client->autoflush(1);

		# Fork off so we can multitask
		my $pid = fork();

		if( $pid ) {
			# We are the parent pid, add to child pids
			push(@children, $pid);
		}
		elsif ( $pid == 0 ) {
			# We are child
			# Print pid to client and close

			client_start($client);

			close $client;
			exit 0;
		}
		else {
			die "couldnt fork: $!\n";
		}
	}	
}

sub client_start {
	my $client = shift;
	my (@headers, %request, %request_data);

	# Set line endings
	local $/ = Socket::CRLF;

	while(<$client>) {
		chomp;

		if( /\s*(\w+)\s*([^\s]+)\s*HTTP\/(\d.\d)/ ) {
			# Main HTTP Request
			$request{METHOD} = uc $1;
			$request{URL} = $2;
			$request{HTTP_VERSION} = $3;
 		}
		elsif( /:/ ) {
			# Standard headers
			my( $type, $val ) = split /:/, $_, 2;
			$type =~ s/^\s+//;
			foreach( $type, $val ) {
				s/^\s+//;
				s/\s+$//;
			}
			$request{lc $type} = $val;
		}
		elsif( /^$/ ) {
			read( $client, $request{CONTENT}, $request{'content-length'})
			if defined $request{'content-length'};
			last;
		}
	}

	# Sort out the request method
	if( $request{METHOD} eq 'GET' ) {
		if( $request{URL} =~ /(.*)\?(.*)/ ) {  # Contains ? in url
			$request{URL} = $1;
			$request{CONTENT} = $2;
			%request_data = parse_http_data($request{CONTENT});
		}
		else {
			%request_data = ();
		}

		$request_data{"_method"} = 'GET';
	}
	elsif( $request{METHOD} eq 'POST' ) {
		if( $request{URL} =~ /(.*)\?(.*)/ ) {  # Contains ? in url
			$request{URL} = $1;
			$request{CONTENT}.= '&' . $2;
		}
		%request_data = parse_http_data($request{CONTENT});

		$request_data{"_method"} = 'POST';
	}
	else {
		$request_data{"_method"} = 'ERROR';
	}

	$request{DATA} = \%request_data;

	# Now we know have the request lets try finding the file
	my $localfile = substr $request{URL}, 1;

	if( my $file = find_local_file($localfile) ) {
		my($content, $header);

		# Send Response
		if( open(FILE, "<$file") ) {
			$content = '';

			my $buffer;
			while( read(FILE, $buffer, 4096) ) {
				$content.= $buffer;
			}

			$request_data{status} = 200;

			push @{$request_data{RESPONSE_HEADERS}}, { 'Content-Type' => file_mimetype($file) };
			push @{$request_data{RESPONSE_HEADERS}}, { 'Content-Length' => length($content) };

			print_headers($client, \%request_data, $request_data{RESPONSE_STATUS});

			print $client $content;
		}
		else {
			$request_data{status} = 404;

			push @{$request_data{RESPONSE_HEADERS}}, { 'Content-Type' => 'text/text' };

			print_headers($client, \%request_data);

			print $client "<html><body>404 Not Found</body></html>";
		}
		close(FILE);
	}
	else {
		my $tmpl_content = '';
		my $buffer = '';

		if( open(FILE, "<template.tmpl") ) {
			$tmpl_content = '';

			while( read(FILE, $buffer, 4096) ) {
				$tmpl_content.= $buffer;
			}
		}

		my $pagelinks = make_menu();

		my %response = route_request(\%request);

		my $pagetitle = $response{title};
		my $pagebody = $response{body};

		$request_data{status} = $response{status};

		$tmpl_content =~ s/\$pagelinks/$pagelinks/g;
		$tmpl_content =~ s/\$pagetitle/$pagetitle/g;
		$tmpl_content =~ s/\$pagebody/$pagebody/g;

		push @{$request_data{RESPONSE_HEADERS}}, { 'Content-Type' => 'text/html' };
		push @{$request_data{RESPONSE_HEADERS}}, { 'Content-Length' => length($tmpl_content) };

		print_headers($client, \%request_data);

		print $client $tmpl_content;
	}
}

sub http_response_status
{
	my $status = shift;

	if($status == 200) {
		return "HTTP/1.0 200 OK";
	}
	elsif($status == 404) {
		return "HTTP/1.0 404 Not Found";
	}
	elsif($status == 401) {
		return "HTTP/1.1 401 Access Denied";
	}
	else {
		return "HTTP/1.0 404 Not Found";
	}
}

sub route_request
{
	my $request = shift;
	my %response;
	my $url = substr $request->{URL}, 1;

	for(my $i = 0; $i < @{$SERVER{MODULES}}; $i++) {
		my %module = %{$SERVER{MODULES}[$i]};

		if(($module{module_name} eq $url) || ($module{module_name} eq '' && $url eq 'home')) {
			return &{$module{page_routine}}(%{$request});
		}
	}

	$response{status} = "404";
	$response{title} = "404 Not Found";
	$response{body} = "<html><body>404 Not Found</body></html>";
	return %response;
}

sub wait_children
{
	my $tmp_pid;
	# Wait for all client forks to finish
	foreach (@children) {
		$tmp_pid = waitpid($_, 0);
		print "done with pid $tmp_pid\n";
	}
}

sub parse_http_data {
	my $mdata = shift;
	my %mdata;

	foreach( split /&/, $mdata ) {
		my($key, $val) = split /=/;
		$val =~ s/\+/ /g;
		$val =~ s/%(..)/chr(hex($1))/eg;

		$mdata{$key} = [] unless exists $mdata{$key};

		push(@{$mdata{$key}}, $val); 
	}
	return %mdata;
}

sub get_request_header
{
	my $request = shift;
	my $header_name = shift;

	while( my($key, $val) = each(%{$request}) ) {
		if($key eq $header_name) {
			return $val;
		}
	}
	return '';
}

sub print_headers
{
	my $client = shift;
	my $request_data = shift;


	print $client http_response_status($request_data->{status}) . Socket::CRLF;

	while( my($key, $val) = each(%{$SERVER{RESPONSE_HEADERS}}) ) {
		print $client $key . ": " . $val . Socket::CRLF;
	}

	for(my $i = 0; $i < @{$request_data->{RESPONSE_HEADERS}}; $i++) {
		my($key, $val) = each(%{$request_data->{RESPONSE_HEADERS}[$i]});
		print $client $key . ": " . $val . Socket::CRLF;
	}
	print $client Socket::CRLF;
}

1;  # To make sure that we return TRUE statement
