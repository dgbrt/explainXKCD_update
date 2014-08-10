#!/usr/bin/perl
#Copyright (C) 2013 by dgbrt.
#
#This library is free software; you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation; either version 3 of the License, or
#(at your option) any later version.
#
#This library is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.


use strict;
use warnings;
use POSIX qw(strftime);
use HTML::Entities;
use MediaWiki::Bot;

use constant false => 0;
use constant true  => 1;

my $bot;
my $comic_page;
my $comic_num;
my $comic_name;
my $picture_name;
my $picture_uri;
my $comic_titletext;
my $raw;
my %atts;
my $text;
my $date;
my $day;
my @all_comics_old_list;
my $all_comics_line;
my $num;
my $name_test; # Used to check if comicsrow will generate the correct image link.

binmode STDOUT, ':utf8';

if ($#ARGV != 1)
{
    print "usage: xkcd username password\n";
    exit(0);
}

my $user = $ARGV[0];
my $pass = $ARGV[1];


#################################################
# If the comic was processed this day do nothing.
#################################################
$date = strftime "%Y-%m-%d", localtime;
if (-e "/opt/xkcd/$date.txt")
{
    ##print "This day was already processed\n";
    exit(0);
}

########################################################
# Get the latest comic and extract the important content
########################################################
$comic_page = `curl -s http://xkcd.com/`;

($comic_num) = $comic_page =~ /Permanent link to this comic: http:\/\/xkcd.com\/(\d+)/;
($comic_name) = $comic_page =~ /<div id="ctitle">(.*)<\/div>/;
($picture_uri) = $comic_page =~ /Image URL \(for hotlinking\/embedding\): (.*)/;

while( $comic_page =~ /<img\s+([^>]+)>/g )
{
    $raw = $1;
    while( $raw =~ /([^ =]+)\s*=\s*("([^"]+)"|[^\s]+\s*)/g )
    {
	$atts{ $1 } = $3;
    }
    if( $atts{ "src" } eq $picture_uri )
    {
	$comic_titletext = $atts{ "title" };
    }
}

$comic_titletext = decode_entities($comic_titletext);


($picture_name) = $picture_uri =~ /http:\/\/imgs.xkcd.com\/comics\/(.*)/;


###################
# Login to the wiki
###################
$bot = MediaWiki::Bot->new
({
    assert      => 'bot',
    host        => 'explainxkcd.com',
    ###host        => 'localhost',
    path        => '/wiki/api.php',
    debug       => 1, # Turn debugging on, to see what the bot is doing
    login_data  => { username => $user, password => $pass },
})
|| die "Login failed";



##############################
# Tests to avoid wrong uploads
##############################

# Get the number from the LATESTCOMIC template
$text = $bot->get_text("Template:LATESTCOMIC");
$num = $text + 1;
# If the number is not the next expected do nothing
if ($comic_num != $num)
{
    print "ERROR: Comic number does not fit. Should be $comic_num but $num was expected.\n";
    exit(0);
}


# If the page itself exists do nothing
$text = $bot->get_text("$comic_num: $comic_name");
if (defined($text))
{
    print "ERROR: Comic $comic_num: $comic_name exists.\n";
    exit(0);
}


# Check for local page file, if file exists do nothing
if (-e "/opt/xkcd/$comic_num.txt")
{
    print "ERROR: Local file exists.\n";
    exit(0);
}


# Download the new picture
`curl -s $picture_uri -o /opt/xkcd/$picture_name`;


# Create the file to stop the polling if upload is already done
$date = strftime "%Y-%m-%d", localtime;
open(COMICPAGE, ">/opt/xkcd/$date.txt");
print COMICPAGE "$date\n";
close(COMICPAGE);


# Create the local page file (just for further possible investigations)
$day = strftime "%e", localtime;
$date = strftime "%B $day, %Y", localtime;
open(COMICPAGE, ">/opt/xkcd/$comic_num.txt");
print COMICPAGE "{{comic\n";
print COMICPAGE "| number    = $comic_num\n";
print COMICPAGE "| date      = $date\n";
print COMICPAGE "| title     = $comic_name\n";
print COMICPAGE "| image     = $picture_name\n";
print COMICPAGE "| titletext = $comic_titletext\n";
print COMICPAGE "}}\n";
print COMICPAGE "\n";
print COMICPAGE "==Explanation==\n";
print COMICPAGE "{{incomplete}}\n";
print COMICPAGE "\n";
print COMICPAGE "==Transcript==\n";
print COMICPAGE "{{incomplete transcript}}\n";
print COMICPAGE "\n";
print COMICPAGE "{{comic discussion}}\n";
print COMICPAGE "<!-- Include any categories below this line. -->\n";
close(COMICPAGE);


# Local log file
$date = strftime "%Y-%m-%d-%H:%M:%S", localtime;
open(COMICLOG, ">>/opt/xkcd/000_comic_log.txt");
print COMICLOG "$date:";
print COMICLOG " $comic_num -";
print COMICLOG " $comic_name -";
print COMICLOG " $picture_name\n";
close(COMICLOG);



############################################
## If no EXIT criteria did match, do the job
############################################

# Upload the picture
$bot->upload
({
	data	=> "==License==\n{{XKCD file}}\n[[Category:Comic images]]",
    file    => "/opt/xkcd/$picture_name",
    title   => "$picture_name"
})
|| die "Picture upload failed";


# Comic name
$text = "#REDIRECT [[$comic_num: $comic_name]]\n";
$bot->edit
({
    page    => $comic_name,
    text    => $text,
    minor   => false,
    bot     => true,
    summary => "Created by dgbrtBOT",
})
|| die "Comic name failed";

# Comic number
$text = "#REDIRECT [[$comic_num: $comic_name]]\n";
$bot->edit
({
    page    => $comic_num,
    text    => $text,
    minor   => false,
    bot     => true,
    summary => "Created by dgbrtBOT",
})
|| die "Comic number failed";

# Comic page
$day = strftime "%e", localtime;
$day =~ s/^\s+//;
$date = strftime "%B $day, %Y", localtime;
$text = <<END;
{{comic
| number    = $comic_num
| date      = $date
| title     = $comic_name
| image     = $picture_name
| titletext = $comic_titletext
}}

==Explanation==
{{incomplete|Created by a BOT - Please change this comment when editing this page.}}

==Transcript==
{{incomplete transcript}}

{{comic discussion}}
END

$bot->edit
({
    page    => "$comic_num: $comic_name",
    text    => $text,
    minor   => false,
    bot     => true,
    summary => "Created by dgbrtBOT",
})
|| die "Comic page failed";

# Template LATESTCOMIC
$text = "$comic_num";
$bot->edit
({
    page    => "Template:LATESTCOMIC",
    text    => $text,
    minor   => false,
    bot     => true,
    summary => "Changed by dgbrtBOT",
})
|| die "LATESTCOMIC failed";


# List of all comics
$text = $bot->get_text('List of all comics');
@all_comics_old_list = split("\\n", $text);

$text = "";
$date = strftime "%Y-%m-%d", localtime;
$picture_name =~ s/\_/ /g;
$name_test = $comic_name;	# This may be longer than it needs to be.
$name_test = s/\_/ /g;		# In my defence, I have 20 minutes of Perl
$name_test = lc($name_test);# experience.

foreach $all_comics_line (@all_comics_old_list)
{
    if ($all_comics_line eq "!Date<onlyinclude>")
    {
        $text .= "$all_comics_line\n";
        if ($picture_name eq $name_test)
        {
			$text .= "{{comicsrow|$comic_num|$date|$comic_name}}\n";
		}
		else
		{
			$text .= "{{comicsrow|$comic_num|$date|$comic_name|$picture_name}}\n";
		}
    }
    else
    {
        $text .= "$all_comics_line\n";
    }
}

$bot->edit
({
    page    => 'List of all comics',
    text    => $text,
    minor   => false,
    bot     => true,
    summary => 'Changed by dgbrtBOT',
})
|| die "List of all comics";

