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

use File::Find;
use MIME::Base64;

# Test if a local file is ready to send back
sub file_mimetype {
	my $filename = shift;
	my $ext = ($filename =~ m/([^.]+)$/)[0];

	if( $ext eq 'css' ) {
		return 'text/css';
	}
	elsif( $ext eq 'html' ) {
		return 'text/html';
	}
	elsif( $ext eq 'js' ) {
		return 'text/javascript';
	}
	return 'text/html';
}

# Test if a local file is ready to send back
sub find_local_file {
	my $file = shift;

	if( defined($file) ) {
		if( $file eq '' ) {
			foreach( @{$SERVER{DEFAULT_FILES}} ) {
				if( -f $SERVER{DOCUMENT_ROOT} . $_ ) {
					return $SERVER{DOCUMENT_ROOT} . $_;
				}
			}
		}
		else {
			if( -f $SERVER{DOCUMENT_ROOT} . $file ) {
				return $SERVER{DOCUMENT_ROOT} . $file;
			}
		}
	}

	return "";
}

# Test if a name is already in the array
sub name_in_array
{
	my $search_name = shift;
	my @arr = shift;
	my $i;

	for( $i = 0; $i < @arr; $i++ ) {
		if( $arr[$i]{name} eq $search_name ) {
			return $i;
		}
	}

	return -1;
}

sub make_menu
{
	my $server_data = shift;
	my $str = '';

	my @modules = sort {
			$$a{rank} <=> $$b{rank};
		} @{$SERVER{MODULES}};

	foreach(@modules) {
		my %module = %{$_};

		if( $module{page_link} ne "" ) {
			$str.= '<div><a href="/' . $module{page_link} . '">' . $module{page_link_title} . '</a></div>' . "\n";
		}

	}

	return $str;
}

sub include_modules
{
	my $server_data = shift;

	use lib "../modules";
	$SERVER{MODULES} = [];

	find(sub {
		include_module_file($File::Find::name, \%{$SERVER}) if(/\.module$/);
	}, "modules"); #custom subroutine find, parse $dir
}

sub authorized
{
	my $auth = shift;
	my @user_pass;

	if($auth ne '') {
		my @auth = split / /, $auth;
		@user_pass = split /:/, decode_base64(@auth[1]);
	}
	else {
		return 0;
	}

	open (FILE, "$SERVER{DATA_ROOT}/authed_users.lst")
		or return "Can't open 'data/authed_users.lst' for reading: $!\n";

	# Set line endings for files
	local $/ = "\n";

	while ($line = <FILE>) {
		my @fuser_pass = split /:/, $line;

		chomp @user_pass[0];
		chomp @user_pass[1];
		chomp @fuser_pass[0];
		chomp @fuser_pass[1];

		if(@fuser_pass[0] eq @user_pass[0] && @fuser_pass[1] eq @user_pass[1]) {
			close(FILE);
			return 1;
		}
	}
	close(FILE);
	return 0;
}

sub include_module_file
{
	my $file = shift;
	my $request_data = shift;

	no strict 'refs';

	require("../" . $file);

	# Strip out leading modules and .module
	$file =~ s/modules//;
	$file =~ s/\///;
	$file =~ s/.module//;

	my %header = &{$file}();

#	\&{%header->{page_routine}}();
	push @{$SERVER{MODULES}}, \%header;
}

1;  # To make sure that we return TRUE statement
