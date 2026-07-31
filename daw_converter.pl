#!/usr/bin/env perl
# REAPER (.rpp) <-> Logic Pro (.logicx / FCPXML) Converter Engine in Perl
# Packages full REAPER project folders into self-contained Logic Pro (.logicx) bundles.

use strict;
use warnings;
use File::Basename;
use File::Copy;
use File::Path qw(make_path);

my $input = $ARGV[0];
my $output = $ARGV[1];

if (!$input) {
    print "Usage: daw_converter.pl <input_file.rpp> [<output_bundle.logicx>]\n";
    exit 1;
}

if (! -e $input) {
    print "Error: Input file '$input' not found.\n";
    exit 1;
}

my ($filename, $dirs, $suffix) = fileparse($input, qr/\.[^.]*/);

if (lc($suffix) eq '.rpp') {
    $output ||= "$filename.logicx";
    $output .= ".logicx" unless $output =~ /\.logicx$/i;
    package_rpp_to_logicx($input, $output);
} else {
    print "Error: Input file must be a REAPER project file (.rpp)\n";
    exit 1;
}

sub package_rpp_to_logicx {
    my ($in_path, $out_bundle) = @_;
    my $in_dir = dirname($in_path);

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

    # Create .logicx bundle structure
    my $media_dir = "$out_bundle/Media/Audio Files";
    make_path($media_dir);

    my $copied_count = 0;
    for my $t (@tracks) {
        for my $i (@{$t->{items}}) {
            if ($i->{file}) {
                my $fname = basename($i->{file});
                my @candidates = (
                    "$in_dir/$i->{file}",
                    "$in_dir/$fname",
                    "$in_dir/audio/$fname",
                    "$in_dir/media/$fname"
                );
                
                my $found = undef;
                for my $cand (@candidates) {
                    if (-f $cand) {
                        $found = $cand;
                        last;
                    }
                }

                if ($found) {
                    copy($found, "$media_dir/$fname");
                    $copied_count++;
                }
                $i->{rel_file} = "Media/Audio Files/$fname";
            }
        }
    }

    # Generate FCPXML inside .logicx bundle
    my $fcpxml_path = "$out_bundle/Session.fcpxml";
    open my $out, '>:encoding(UTF-8)', $fcpxml_path or die "Could not write $fcpxml_path: $!";
    
    print $out "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    print $out "<!DOCTYPE fcpxml>\n";
    print $out "<fcpxml version=\"1.9\">\n";
    print $out "  <resources>\n";
    print $out "    <format id=\"r1\" name=\"FFVideoFormat1080p24\" frameDuration=\"100/2400s\"/>\n";

    my %assets = ();
    my $asset_id = 2;
    for my $t (@tracks) {
        for my $i (@{$t->{items}}) {
            my $rel = $i->{rel_file} || "Media/Audio Files/$i->{name}.wav";
            if (!$assets{$rel}) {
                $assets{$rel} = "r$asset_id";
                $asset_id++;
                my $dur = sprintf("%.3fs", $i->{length} || 10.0);
                print $out "    <asset id=\"$assets{$rel}\" name=\"$i->{name}\" src=\"file://$rel\" duration=\"$dur\" hasAudio=\"1\" audioSources=\"1\" audioChannels=\"2\" format=\"r1\"/>\n";
            }
        }
    }
    print $out "  </resources>\n";
    print $out "  <library>\n";
    print $out "    <event name=\"$filename\">\n";
    print $out "      <project name=\"$filename\">\n";
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
            my $rel = $i->{rel_file} || "Media/Audio Files/$i->{name}.wav";
            my $aid = $assets{$rel} || "r2";
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

    # Open launcher inside bundle
    my $launcher_path = "$out_bundle/Open in Logic Pro.command";
    open my $lout, '>:encoding(UTF-8)', $launcher_path;
    print $lout "#!/bin/bash\nDIR=\"\$( cd \"\$( dirname \"\${BASH_SOURCE[0]}\" )\" >/dev/null 2>&1 && pwd )\"\nopen -a \"Logic Pro\" \"\$DIR/Session.fcpxml\"\n";
    close $lout;
    chmod 0755, $launcher_path;

    print "🎉 Successfully packaged REAPER project folder into Logic Pro bundle: '$out_bundle'\n";
}
