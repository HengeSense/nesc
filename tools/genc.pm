# This file is part of the nesC compiler.
#    Copyright (C) 2002 Intel Corporation
# 
# The attached "nesC" software is provided to you under the terms and
# conditions of the GNU General Public License Version 2 as published by the
# Free Software Foundation.
# 
# nesC is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with nesC; see the file COPYING.  If not, write to
# the Free Software Foundation, 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

true;

sub gen() {
    my ($classname, @spec) = @_;
    my ($p, $up);

    require migdecode;
    &decode(@spec);

    if (!$ofile || !($ofile =~ /\.h$/)) {
	&usage("You must use -o <somefilename>.h when generating C");
    }
    $cfile = $ofile;
    $cfile =~ s/\.h$/.c/;
    $hfile = $ofile;
    $hfile =~ s/.*[\\\/]//;

    $c_prefix = $message_type if !defined($c_prefix);
    $p = $c_prefix;

    print "/**\n";
    print " * This file is automatically generated by mig. DO NOT EDIT THIS FILE.\n";
    print " * This file defines the layout of the '$message_type' message type.\n";
    print " */\n\n";

    print "#ifndef \U${p}_H\n";
    print "#define \U${p}_H\n";

    print "#include <message.h>\n";

    print "\nenum {\n";
    print "  /** The default size of this message type in bytes. */\n";
    print "  \U${p}_SIZE = $size,\n\n";

    print "  /** The Active Message type associated with this message. */\n";
    print "  \U${p}_AM_TYPE = $amtype,\n";

    for (@fields) {
	($field, $type, $bitlength, $offset, $amax, $abitsize, $aoffset) = @{$_};

        # Get field type and accessor
	$cfield = $field;
	$cfield =~ s/\./_/g;
	$uf = "\U${c_prefix}_\U${cfield}";
	($ctype, $c_access) = &cbasetype($type, $bitlength);

	print "\n  /* Field $field: ";
	if (@$amax) {
	  print "type ${ctype}[], element size (bits) $bitlength */\n";
	} else {
	  print "type $ctype, offset (bits) $offset, size (bits) $bitlength */\n";
	}

	if (!@$amax) { # not array
	    print_bitsbytes_constant($uf, "offset", $field, $offset, $offset / 8);
	    print_bitsbytes_constant($uf, "size", $field, $bitlength, ($bitlength + 7) / 8);
	} else { # array
	    print_bitsbytes_constant($uf, "elementsize", $field,
				     $bitlength, ($bitlength + 7) / 8);
	    print_constant($uf, "numdimensions", $#$amax + 1,
			   "The number of dimensions in the array '$field'");

	    ### Total number of elements and for each dimension
	    $total = 1; $i = 1;
	    for $n (@$amax) {
		$total *= $n;
		print_constant($uf, "numelements_$i", $n,
			       "Number of elements in dimension $i of array '$field'");
		$i++;
	    }
	    if ($total != 0) { # Only print this for fixed-sized arrays 
		print_constant($uf, "numelements", $total,
			       "Total number of elements in the array '$field'");
	    }
	}
    }
    print "};\n\n";


    for (@fields) {
	($field, $type, $bitlength, $offset, $amax, $abitsize, $aoffset) = @{$_};

        # Get field type and accessor
	$cfield = $field;
	$cfield =~ s/\./_/g;
	$uf = "${c_prefix}_${cfield}";
	($ctype, $c_access) = &cbasetype($type, $bitlength);

	if (!@$amax) { # not array
	    print_proto($uf, $ctype, "get", "tmsg_t *msg",
			"Return the value of the field '$field'");
	    print_proto($uf, "void", "set", "tmsg_t *msg, $ctype value",
			"Set the value of the field '$field'");
	} else { # array
	    $index = 0;
	    @args = map { $index++; "size_t index$index" } @{$amax};
	    $argspec = join(", ", @args);

	    print_proto($uf, "size_t", "offset", $argspec,
			"Return the byte offset of an element of array '$field'");
	    print_proto($uf, $ctype, "get", "tmsg_t *msg, $argspec",
			"Return an element of the array '$field'");
	    print_proto($uf, "void", "set", "tmsg_t *msg, $argspec, $ctype value",
			"Set an element of the array '$field'");
	    print_proto($uf, "size_t", "offsetbits", $argspec,
			"Return the bit offset of an element of array '$field'");
	}
    }

    print "#endif\n";

    close STDOUT;
    if (!open STDOUT, ">$cfile") {
	print STDERR "failed to create $cfile\n";
	exit 1;
    }

    print "/**\n";
    print " * This file is automatically generated by mig. DO NOT EDIT THIS FILE.\n";
    print " * This file implements the functions for encoding and decoding the\n";
    print " * '$message_type' message type. See $hfile for more details.\n";
    print " */\n\n";
    print "#include <message.h>\n";
    print "#include \"$hfile\"\n\n";

    for (@fields) {
	($field, $type, $bitlength, $offset, $amax, $abitsize, $aoffset) = @{$_};

        # Get field type and accessor
	$cfield = $field;
	$cfield =~ s/\./_/g;
	$uf = "${c_prefix}_${cfield}";
	($ctype, $c_access) = &cbasetype($type, $bitlength);

	if (!@$amax) { # not array
	    print_next_header(); # get
	    print "{\n  return tmsg_read_$c_access(msg, $offset, $bitlength);\n}\n\n";
	    print_next_header(); # set
	    print "{\n  tmsg_write_$c_access(msg, $offset, $bitlength, value);\n}\n\n";
	} else { # array
	    $index = 0;
	    @passargs = map { $index++; "index$index" } @{$amax};
	    $passargs = join(", ", @passargs);

	    print_next_header(); # offset
	    print "{\n  return ${uf}_offsetbits($passargs) / 8;\n}\n\n";
	    print_next_header(); # get
	    print "{\n  return tmsg_read_$c_access(msg, ${uf}_offset_bits($passargs), $bitlength);\n}\n\n";
	    print_next_header(); # set
	    print "{\n  tmsg_write_$c_access(msg, ${uf}_offset_bits($passargs), $bitlength, value);\n}\n\n";
	    print_next_header(); # offsetbits
	    print_offsetbits($offset, $amax, $abitsize, $aoffset);
	}
    }

}

sub cbasetype()
{
    my ($basetype, $bitlength) = @_;
    my $ctype, $acc;

    if ($basetype eq "F" || $basetype eq "D" || $basetype eq "LD") {
      $acc = "float_le";
      $ctype = "float";
    }
    else {
	# Pick the C type whose signedness matches and which is the smallest that
	# is greater or equal to the field size
	if ($bitlength <= 8) { $ctype = "int8_t"; }
	elsif ($bitlength <= 16) { $ctype = "int16_t"; }
	elsif ($bitlength <= 32) { $ctype = "int32_t"; }
	else { $ctype = "int64_t"; }

	$acc = "";
	if ($basetype eq "U" || $basetype eq "BU") {
	    $ctype = "u$ctype";
	    $acc .= "u";
	}
	if ($basetype eq "BU" || $basetype eq "BI") {
	    $acc .= "be";
	}
	else {
	    $acc .= "le";
	}
    }

    return ($ctype, $acc);
}

sub print_bitsbytes_constant {
    my ($uf, $name, $field, $x, $xbytes) = @_;
    my ($uname, $cname);

    $xbytes = int($xbytes);

    print "  /** \u$name (in bytes) of the field '$field' */\n";
    if ((int($x) % 8) != 0) {
	print "  /*  WARNING: This field is not byte-aligned (bit $name $x). */\n";
    }
    print "  ${uf}_\U$name = $xbytes,\n";

    print "  /** \u$name (in bits) of the field '$field' */\n";
    print "  ${uf}_\U${name}BITS = $x,\n";
}

sub print_constant {
    my ($uf, $name, $x, $desc) = @_;

    print "  /** $desc. */\n";
    print "  ${uf}_\U$name = $x,\n";
}

sub print_proto {
    my ($uf, $ctype, $name, $args, $desc) = @_;
    my ($hdr);

    $hdr = "$ctype ${uf}_${name}($args)";
    push @headers, $hdr;

    print "/**\n";
    print " * $desc\n";
    print " */\n";
    print "$hdr;\n\n";
}

sub print_next_header {
    my ($hdr);

    $hdr = shift @headers;
    print "$hdr\n";
}

sub print_offsetbits()
{
    my ($offset, $max, $bitsize, $aoffset) = @_;

    print "{\n";
    print "  size_t offset = $offset;\n";
    for ($i = 1; $i <= @$max; $i++) {
	# check index bounds. 0-sized arrays don't get an upper-bound check
	# (they represent variable size arrays. Normally they should only
	# occur as the first-dimension of the last element of the structure)
	if ($$max[$i - 1] != 0) {
	    print "  if (index$i >= $$max[$i - 1]) { tmsg_fail(); return (size_t)-1; }\n";
	}
	print "  offset += $$aoffset[$i - 1] + index$i * $$bitsize[$i - 1];\n";
    }
    print "  return offset;\n";
    print "}\n\n";
}

