#!/local/bin/perl
# ------------------------------------------------------------------
#                          2-Word-post-v2.0
# Perl post-processor for MS Word RFC/Internet-draft template output
#
#                              J. Touch
#                           touch@isi.edu
#                      http://www.isi.edu/touch
#
#            USC Information Sciences Institute (USC/ISI)
#               Marina del Rey, California 90292, USA
#                         Copyright (c) 2004-2016
#
# Revision date: Oct. 28, 2016
# ------------------------------------------------------------------
#
# Copyright (c) 2004-2016 by the University of Southern California.
# All rights reserved.
#
# Permission to use, copy, modify, and distribute this software and
# its documentation in source and binary forms for non-commercial
# purposes and without fee is hereby granted, provided that the
# above copyright notice appear in all copies and that both the
# copyright notice and this permission notice appear in supporting
# documentation, and that any documentation, advertising materials,
# and other materials related to such distribution and use
# acknowledge that the software was developed by the University of
# Southern California, Information Sciences Institute.  The name of
# the University may not be used to endorse or promote products
# derived from this software without specific prior written
# permission.
#
# THE UNIVERSITY OF SOUTHERN CALIFORNIA MAKES NO REPRESENTATIONS
# ABOUT THE SUITABILITY OF THIS SOFTWARE FOR ANY PURPOSE.  THIS
# SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
# ------------------------------------------------------------------
#
# usage:  
#        2-Word-post-v2.0.pl [inputfile.txt] > [outputfile.txt]
#
# function:
#     replaces -^M    - with - (regardless of space after ^M) (seen 2016)
#     removes indent on each line (blank print margin, typ. 5 chars)
#     converts cr/lf to cr 
#     converts 'smart quotes' to regular quotes (single and double)
#       this includes converting '' to "
#     converts 'smart hyphens' (EM-dash, EN-dash) to regular hyphen
#     omits blank lines between footer and next-page header
#     inserts formfeed (ff) between footer and next-page header
#     removes end-of-line whitespace
#     checks for illegal chars (not printable ASCII, cr, lf, ff)
#     checks for page lengths exceeded
#     checks for line lengths exceeded
#     prints errors indicating page and line on that page
#
#        illegal character errors are posted to STDERR
#
#        returns the logical OR of codes indicating errors found:
#                0x00 no error
#                0x01 if any illegal characters found
#                0x02 if any page length exceeds $maxpagelen
#                0x04 if any line length exceeds $maxlinelen
#
# ------------------------------------------------------------------

# ------------------------------------------------------------------
# VARIABLES
# ------------------------------------------------------------------

$pagenum = 1;          # start on page 1, not 0

$maxpagelen = 66;      # max lines per page

$maxlinelen = 72;      # max chars per line

                       # specific error codes
%codes = (
           'none' => 0x00,
           'char' => 0x01,
           'page' => 0x02,
           'line' => 0x04,
         );

%codestrings = (
                 'none' => '(no error)',
                 'char' => 'invalid character code',
                 'line' => 'exceeded $maxpagelen lines per page',
                 'page' => 'exceeded $maxlinelen chars per line',
               );

$errorcode = $codes{'none'};

$indentlen = -1;       # how many spaces to eat from the beginning
                       # of each line; ought to be 5. negative flag
                       # means it is not yet initialized

$indentstr = "     ";  # until known otherwise, assume 5 spaces

$killwhite = 1;        # flag kills space between footer, header
                       # start in 'between footer and header' mode,
                       # so eats all whitespace before the first line


# ------------------------------------------------------------------
# ERROR SUBROUTINE
# ------------------------------------------------------------------
sub printerr ($) {
  my ($errstring) = shift;

  print STDERR "ERROR: $codestrings{$errstring} ", 
    "on line $linenum on page $pagenum of text input file\n";
  $errorcode |= $codes{$errstring};
  return;
}


# ------------------------------------------------------------------
# MAIN
# ------------------------------------------------------------------

while ($line = <>) {
  $line =~ s/\-\r\s\s+\-/\-/g; # remove odd hyphen spacing seen in 2016
  $line =~ s/\r//g;         # remove Unix-style end-of-line
  # if this line is NOT empty, start printing again (see below)
  if ($line !~ /^\s*$/) {
    $killwhite = 0;
    if ($indentlen < 0) {
      # discover margin indent
      $line =~ /^((\s)*)/;
      $indentstr = $1;
      $indentlen = length($indentstr);
    }
  }
  # remove the margin indent
  $line =~ s/^($indentstr)//;
  # change special hyphens, quotes to regular ones
  $line =~ s/\221\221/\"/g;
  $line =~ s/\222\222/\"/g;
  $line =~ tr/\221\222\223\224\226\227/\'\'\"\"\-\-/;
  # omit end-of-line whitespace
  $line =~ s/\s+\n/\n/g;
  # print unless we're between the end of one page
  # and the beginning of the next
  if ($killwhite != 1) { 
    # check to see if we have any invalid characters left
    # 012 = new line, 014 = form feed, 015 = carriage return
    # 040-176 = printable ASCIIs  
    if ($line !~ /^([\012\014\015\040-\176])*$/) {
      printerr('char');
      # note - we don't stop here, so we can find all the 
      # unprintable characters in one pass
    } 
    $linenum++;
    if ($linenum > $maxpagelen) {
      printerr('page');
    }
    if (length($line) > $maxlinelen) {
      printerr('line');
    }
    print $line;
  }
  # check to see if this is the end of a page; 
  # if so, then print a form feed (ctl-L), and
  # kill the printing of subsequent empty lines
  if ($line =~ /\[Page \d+\]\s+$/) {
    print "\f\n";
    $killwhite = 1;
    $linenum = 0;
    $pagenum++;
  }
}
exit($errorcode);
