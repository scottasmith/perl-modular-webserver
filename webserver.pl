#!/usr/bin/perl

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

use strict;
use warnings;
use File::Basename;
use Scalar::Util 'reftype';
use Data::Dumper;

#
# GLOBAL DEFINES
#
our %SERVER = ();
$SERVER{DEBUG} = 0;
$SERVER{DOCUMENT_ROOT} = 'public/';
$SERVER{DATA_ROOT} = 'data';
@{$SERVER{DEFAULT_FILES}} = ('index.htm', 'index.html');
%{$SERVER{RESPONSE_HEADERS}} = ('Server' => 'Sco Utilities HTTP Server');

# Include our libraries
#
use lib ".";
require "lib/svr.pl";
require "lib/misc.pl";

# No buffering
$| = 1;

# Watch out for zombies
$SIG{CHLD} = 'IGNORE';

# Setup and create socket
my $port = shift;
defined($port) or die "Usage: $0 portno\n";

include_modules(\%SERVER);

if($SERVER{DEBUG} == 1) {
	start_server($port);
}
else {
	start_daemon_server($port);
}

# wait for thread children to stop
wait_children();

# Exit main program
exit;

