#!/usr/bin/env perl
# REAPER (.rpp) <-> Logic Pro (FCPXML) Converter Engine in Perl
# Runs out-of-the-box on all macOS systems without external dependencies.

use strict;
use warnings;
use File::Basename;

my $input = $ARGV[0];
my $output = $ARGV[1];

if (!$input) {
    print "Usage: daw_converter.pl <input_file> [<output_file>]\n";
    exit 1;
}

if (! -e $input) {
    print "Error: Input file '$input' not found.\n";
    exit 1;
}

my ($filename, $dirs, $suffix) = fileparse($input, qr/\.[^.]*/);

if (lc($suffix) eq '.rpp') {
    $output ||= "$filename.fcpxml";
    rpp_to_fcpxml($input, $output);
} elsif (lc($suffix) eq '.fcpxml' || lc($suffix) eq '.xml') {
    $output ||= "$filename.rpp";
    fcpxml_to_rpp($input, $output);
} else {
    print "Error: Unsupported file format '$suffix'. Must be .rpp or .fcpxml\n";
    exit 1;
}

sub rpp_to_fcpxml {
    my ($in_path, $out_path) = @_;
    open my $fh, '<:encoding(UTF-8)', $in_path or die "Could not open $in_path: $!";
    
    my $tempo = 120.0;
    my @markers = ();
    my @tracks = ();
    
    my $current_track = undef;
    my $current_item = undef;
    my $in_source = 0;
    my $track_num = 0;

    while (my $line = <$fh>) {
        $line =~ s/^\s+|\s+$//g;
        next if $line eq '';

        if ($line =~ /^TEMPO\s+([\d\.]+)/) {
            $tempo = $1;
        } elsif ($line =~ /^MARKER\s+\d+\s+([\d\.]+)\s+"([^"]*)"/) {
            push @markers, { pos => $1, name => $2 };
        } elsif ($line =~ /^<TRACK/) {
            $track_num++;
            $current_track = { name => "Track $track_num", num => $track_num, items => [] };
            push @tracks, $current_track;
        } elsif ($line =~ /^<ITEM/ && $current_track) {
            $current_item = { name => "Item", pos => 0.0, len => 0.0, soffs => 0.0, file => "" };
            push @{$current_track->{items}}, $current_item;
            $in_source = 0;
        } elsif ($line =~ /^<SOURCE/ && $current_item) {
            $in_source = 1;
        } elsif ($line eq '>') {
            if ($in_source) { $in_source = 0; }
            elsif ($current_item) { $current_item = undef; }
            elsif ($current_track) { $current_track = undef; }
        } elsif ($current_item) {
            if ($line =~ /^NAME\s+"?([^"]+)"?/) {
                $current_item->{name} = $1;
            } elsif ($line =~ /^POSITION\s+([\d\.]+)/) {
                $current_item->{pos} = $1;
            } elsif ($line =~ /^LENGTH\s+([\d\.]+)/) {
                $current_item->{length} = $1;
            } elsif ($line =~ /^SOFFS\s+([\d\.]+)/) {
                $current_item->{soffs} = $1;
            } elsif ($line =~ /^FILE\s+"?([^"]+)"?/) {
                $current_item->{file} = $1;
                $current_item->{name} = basename($1) if $current_item->{name} eq "Item";
            }
        } elsif ($current_track) {
            if ($line =~ /^NAME\s+"?([^"]+)"?/) {
                $current_track->{name} = $1;
            }
        }
    }
    close $fh;

    # Generate FCPXML
    my $proj_name = $filename;
    open my $out, '>:encoding(UTF-8)', $out_path or die "Could not write $out_path: $!";
    
    print $out "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    print $out "<!DOCTYPE fcpxml>\n";
    print $out "<fcpxml version=\"1.9\">\n";
    print $out "  <resources>\n";
    print $out "    <format id=\"r1\" name=\"FFVideoFormat1080p24\" frameDuration=\"100/2400s\"/>\n";

    my %assets = ();
    my $asset_id = 2;
    for my $t (@tracks) {
        for my $i (@{$t->{items}}) {
            my $file = $i->{file} || "$i->{name}.wav";
            if (!$assets{$file}) {
                $assets{$file} = "r$asset_id";
                $asset_id++;
                my $dur = sprintf("%.3fs", $i->{length} || 10.0);
                print $out "    <asset id=\"$assets{$file}\" name=\"$i->{name}\" src=\"file://$file\" duration=\"$dur\" hasAudio=\"1\" audioSources=\"1\" audioChannels=\"2\" format=\"r1\"/>\n";
            }
        }
    }
    print $out "  </resources>\n";
    print $out "  <library>\n";
    print $out "    <event name=\"$proj_name\">\n";
    print $out "      <project name=\"$proj_name\">\n";
    print $out "        <sequence duration=\"300.000s\" format=\"r1\" tcStart=\"0s\" tcFormat=\"NDF\">\n";
    print $out "          <spine>\n";

    for my $m (@markers) {
        my $mpos = sprintf("%.3fs", $m->{pos});
        print $out "            <marker start=\"$mpos\" duration=\"0s\" value=\"$m->{name}\"/>\n";
    }

    for my $t (@tracks) {
        my $role = lc($t->{name});
        $role =~ s/\s+/_/g;
        for my $i (@{$t->{items}}) {
            my $aid = $assets{$i->{file} || "$i->{name}.wav"} || "r2";
            my $offset = sprintf("%.3fs", $i->{pos});
            my $start = sprintf("%.3fs", $i->{soffs});
            my $dur = sprintf("%.3fs", $i->{length});
            print $out "            <asset-clip name=\"$i->{name}\" ref=\"$aid\" offset=\"$offset\" start=\"$start\" duration=\"$dur\" audioRole=\"$role\" lane=\"$t->{num}\"/>\n";
        }
    }

    print $out "          </spine>\n";
    print $out "        </sequence>\n";
    print $out "      </project>\n";
    print $out "    </event>\n";
    print $out "  </library>\n";
    print $out "</fcpxml>\n";
    close $out;

    print "✓ Successfully converted '$in_path' -> '$out_path'\n";
}

sub fcpxml_to_rpp {
    my ($in_path, $out_path) = @_;
    open my $fh, '<:encoding(UTF-8)', $in_path or die "Could not open $in_path: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    my @markers = ();
    while ($content =~ /<marker\s+start="([\d\.]+)s"[^>]*value="([^"]*)"/g) {
        push @markers, { pos => $1, name => $2 };
    }

    my %tracks_map = ();
    while ($content =~ /<asset-clip\s+name="([^"]*)"[^>]*offset="([\d\.]+)s"[^>]*start="([\d\.]+)s"[^>]*duration="([\d\.]+)s"[^>]*audioRole="([^"]*)"/g) {
        my ($item_name, $pos, $soffs, $dur, $role) = ($1, $2, $3, $4, $5);
        my $tname = ucfirst($role);
        $tname =~ s/_/ /g;
        
        $tracks_map{$tname} ||= [];
        push @{$tracks_map{$tname}}, { name => $item_name, pos => $pos, soffs => $soffs, len => $dur };
    }

    open my $out, '>:encoding(UTF-8)', $out_path or die "Could not write $out_path: $!";
    print $out "<REAPER_PROJECT 0.1 \"7.0/macOS\" 1700000000\n";
    print $out "  RIPPLE 0\n  GROUPS 0\n  GROUPOVR 0\n";
    print $out "  TEMPO 120 4 4\n";

    my $mid = 1;
    for my $m (@markers) {
        my $mpos = sprintf("%.6f", $m->{pos});
        print $out "  MARKER $mid $mpos \"$m->{name}\" 0 0 1\n";
        $mid++;
    }

    my $tnum = 1;
    for my $tname (keys %tracks_map) {
        print $out "  <TRACK\n";
        print $out "    NAME \"$tname\"\n";
        print $out "    VOLPAN 1.000000 0.000000 1.0 -1.0\n";

        for my $item (@{$tracks_map{$tname}}) {
            my $pos = sprintf("%.6f", $item->{pos});
            my $len = sprintf("%.6f", $item->{len});
            my $soffs = sprintf("%.6f", $item->{soffs});
            print $out "    <ITEM\n";
            print $out "      POSITION $pos\n";
            print $out "      LENGTH $len\n";
            print $out "      SOFFS $soffs\n";
            print $out "      NAME \"$item->{name}\"\n";
            print $out "      <SOURCE WAVE\n";
            print $out "        FILE \"$item->{name}.wav\"\n";
            print $out "      >\n";
            print $out "    >\n";
        }
        print $out "  >\n";
        $tnum++;
    }

    print $out ">\n";
    close $out;

    print "✓ Successfully converted '$in_path' -> '$out_path'\n";
}
