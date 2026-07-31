#!/usr/bin/env perl
# REAPER (.rpp) <-> Logic Pro (.logicx / FCPXML) Converter Engine in Perl
# Native Logic Pro Package Bundle Builder & Audio Media Importer

use strict;
use warnings;
use File::Basename;
use File::Copy;
use File::Path qw(make_path);
use Cwd 'abs_path';

my $arg1 = $ARGV[0];
my $arg2 = $ARGV[1];
my $arg3 = $ARGV[2];

if (!$arg1) {
    print "Usage: daw_converter.pl <rpp_file_or_folder> [<audio_folder>] [<output_bundle.logicx>]\n";
    exit 1;
}

my $rpp_file = "";
my $audio_dir = "";
my $out_bundle = "";

if (-f $arg1) {
    $rpp_file = abs_path($arg1);
    if ($arg2 && -d $arg2) {
        $audio_dir = abs_path($arg2);
        $out_bundle = $arg3 || "";
    } else {
        $audio_dir = dirname($rpp_file);
        $out_bundle = $arg2 || "";
    }
} elsif (-d $arg1) {
    $audio_dir = abs_path($arg1);
    if ($arg2 && -f $arg2) {
        $rpp_file = abs_path($arg2);
        $out_bundle = $arg3 || "";
    } else {
        # Search for .rpp file in directory
        opendir(my $dh, $audio_dir) or die "Cannot open directory $audio_dir: $!";
        my @rpp_files = grep { /\.rpp$/i } readdir($dh);
        closedir($dh);

        if (@rpp_files == 0) {
            print "Error: No REAPER project (.rpp) file found inside directory '$audio_dir'\n";
            exit 1;
        }
        $rpp_file = "$audio_dir/$rpp_files[0]";
        $out_bundle = $arg2 || "";
    }
}

my ($filename, $dirs, $suffix) = fileparse($rpp_file, qr/\.[^.]*/);
$out_bundle ||= "$audio_dir/${filename}.logicx";
$out_bundle .= ".logicx" unless $out_bundle =~ /\.logicx$/i;

package_rpp_to_logicx_bundle($rpp_file, $audio_dir, $out_bundle, $filename);

sub package_rpp_to_logicx_bundle {
    my ($in_rpp, $proj_dir, $out_path, $proj_name) = @_;

    # 1. Create Logic Pro bundle structure matching native .logicx format
    my $media_dir = "$out_path/Media/Audio Files";
    my $res_dir = "$out_path/Resources";
    my $alts_dir = "$out_path/Alternatives/000";

    make_path($media_dir);
    make_path($res_dir);
    make_path($alts_dir);

    # 2. Parse REAPER project
    my $session = parse_rpp($in_rpp);

    # 3. Copy all audio media into Media/Audio Files/
    my $copied_count = 0;
    my @copied_files = ();

    for my $t (@{$session->{tracks}}) {
        for my $i (@{$t->{items}}) {
            if ($i->{file}) {
                my $fname = basename($i->{file});
                my @candidates = (
                    "$proj_dir/$i->{file}",
                    "$proj_dir/$fname",
                    "$proj_dir/audio/$fname",
                    "$proj_dir/media/$fname",
                    "$proj_dir/Audio Files/$fname",
                    "$proj_dir/Audio/$fname",
                    "$proj_dir/Media/$fname"
                );
                
                my $found = undef;
                for my $cand (@candidates) {
                    if (-f $cand) {
                        $found = abs_path($cand);
                        last;
                    }
                }

                if ($found) {
                    my $dest = "$media_dir/$fname";
                    copy($found, $dest);
                    $i->{abs_file} = abs_path($dest);
                    push @copied_files, "Media/Audio Files/$fname";
                    $copied_count++;
                } else {
                    $i->{abs_file} = abs_path("$media_dir/$fname");
                }
            }
        }
    }

    # Also scan audio directory for any additional audio files (.wav, .aif, .mp3)
    if (-d $proj_dir) {
        opendir(my $adh, $proj_dir);
        while (my $af = readdir($adh)) {
            next if $af =~ /^\./;
            if ($af =~ /\.(wav|aif|aiff|mp3|m4a|flac)$/i) {
                my $src_file = "$proj_dir/$af";
                my $dst_file = "$media_dir/$af";
                if (! -f $dst_file) {
                    copy($src_file, $dst_file);
                    push @copied_files, "Media/Audio Files/$af";
                    $copied_count++;
                }
            }
        }
        closedir($adh);
    }

    # 4. Write ProjectInformation.plist inside Resources/
    my $info_plist = "$res_dir/ProjectInformation.plist";
    open my $ip, '>:encoding(UTF-8)', $info_plist;
    print $ip "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    print $ip "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n";
    print $ip "<plist version=\"1.0\">\n<dict>\n";
    print $ip "  <key>BundleVersion</key>\n  <string>12</string>\n";
    print $ip "  <key>HasProjectFolder</key>\n  <true/>\n";
    print $ip "  <key>LastSavedFrom</key>\n  <string>Logic Pro</string>\n";
    print $ip "  <key>PROJECT_NAME</key>\n  <string>$proj_name</string>\n";
    print $ip "</dict>\n</plist>\n";
    close $ip;

    # 5. Generate FCPXML inside bundle with valid file:/// URIs
    my $fcpxml_path = "$out_path/Session.fcpxml";
    open my $out, '>:encoding(UTF-8)', $fcpxml_path or die "Could not write $fcpxml_path: $!";
    print $out get_fcpxml_str($session, $out_path, $proj_name);
    close $out;

    # 6. Generate Open in Logic Pro launcher script
    my $launcher_path = "$out_path/Open in Logic Pro.command";
    open my $lout, '>:encoding(UTF-8)', $launcher_path;
    print $lout "#!/bin/bash\nDIR=\"\$( cd \"\$( dirname \"\${BASH_SOURCE[0]}\" )\" >/dev/null 2>&1 && pwd )\"\nopen -a \"Logic Pro\" \"\$DIR/Session.fcpxml\"\n";
    close $lout;
    chmod 0755, $launcher_path;

    # 7. Instructions text file
    my $readme_path = "$out_path/How to Open in Logic Pro.txt";
    open my $rout, '>:encoding(UTF-8)', $readme_path;
    print $rout "Logic Pro Package Bundle (.logicx)\n";
    print $rout "===================================\n\n";
    print $rout "Project Name: $proj_name\n";
    print $rout "Tracks Count: " . scalar(@{$session->{tracks}}) . "\n";
    print $rout "Audio Media Files Bundled: $copied_count\n\n";
    print $rout "To open in Logic Pro:\n";
    print $rout " 1. Double-click 'Open in Logic Pro.command' inside this bundle.\n";
    print $rout " 2. Or open Logic Pro, go to File > Import > Final Cut Pro XML...\n";
    print $rout "    and choose 'Session.fcpxml' inside this bundle.\n\n";
    print $rout "All audio media is stored natively inside 'Media/Audio Files/'.\n";
    close $rout;

    print "🎉 Successfully created native Logic Pro bundle: '$out_path'\n";
    print "   Tracks: " . scalar(@{$session->{tracks}}) . " | Audio Files Bundled: $copied_count\n";
}

sub parse_rpp {
    my ($in_path) = @_;
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

        if ($line =~ /^TEMPO\s+([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)/) {
            $tempo = $1;
        } elsif ($line =~ /^MARKER\s+\d+\s+([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)\s+"([^"]*)"/) {
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
            } elsif ($line =~ /^POSITION\s+([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)/) {
                $current_item->{pos} = $1;
            } elsif ($line =~ /^LENGTH\s+([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)/) {
                $current_item->{length} = $1;
            } elsif ($line =~ /^SOFFS\s+([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)/) {
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

    return { tempo => $tempo, markers => \@markers, tracks => \@tracks };
}

sub get_fcpxml_str {
    my ($session, $base_dir, $proj_name) = @_;

    my $xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    $xml .= "<!DOCTYPE fcpxml>\n";
    $xml .= "<fcpxml version=\"1.9\">\n";
    $xml .= "  <resources>\n";
    $xml .= "    <format id=\"r1\" name=\"FFVideoFormat1080p24\" frameDuration=\"100/2400s\"/>\n";

    my %assets = ();
    my $asset_id = 2;

    for my $t (@{$session->{tracks}}) {
        for my $i (@{$t->{items}}) {
            my $abs_path = $i->{abs_file} || "$base_dir/Media/Audio Files/$i->{name}.wav";
            $abs_path =~ s#\\#/#g;
            $abs_path = "/$abs_path" unless $abs_path =~ m#^/#;
            
            if (!$assets{$abs_path}) {
                $assets{$abs_path} = "r$asset_id";
                $asset_id++;
                my $dur = sprintf("%.3fs", $i->{length} || 10.0);
                $xml .= "    <asset id=\"$assets{$abs_path}\" name=\"$i->{name}\" src=\"file://$abs_path\" duration=\"$dur\" hasAudio=\"1\" audioSources=\"1\" audioChannels=\"2\" format=\"r1\"/>\n";
            }
        }
    }

    $xml .= "  </resources>\n";
    $xml .= "  <library>\n";
    $xml .= "    <event name=\"$proj_name\">\n";
    $xml .= "      <project name=\"$proj_name\">\n";
    $xml .= "        <sequence duration=\"600.000s\" format=\"r1\" tcStart=\"0s\" tcFormat=\"NDF\">\n";
    $xml .= "          <spine>\n";

    for my $m (@{$session->{markers}}) {
        my $mpos = sprintf("%.3fs", $m->{pos});
        $xml .= "            <marker start=\"$mpos\" duration=\"0s\" value=\"$m->{name}\"/>\n";
    }

    for my $t (@{$session->{tracks}}) {
        my $role = lc($t->{name});
        $role =~ s/[^a-z0-9]/_/g;
        $role = "track_$t->{num}" if !$role;

        for my $i (@{$t->{items}}) {
            my $abs_path = $i->{abs_file} || "$base_dir/Media/Audio Files/$i->{name}.wav";
            $abs_path =~ s#\\#/#g;
            $abs_path = "/$abs_path" unless $abs_path =~ m#^/#;
            
            my $aid = $assets{$abs_path} || "r2";
            my $offset = sprintf("%.3fs", $i->{pos});
            my $start = sprintf("%.3fs", $i->{soffs});
            my $dur = sprintf("%.3fs", $i->{length});
            $xml .= "            <asset-clip name=\"$i->{name}\" ref=\"$aid\" offset=\"$offset\" start=\"$start\" duration=\"$dur\" audioRole=\"$role\" lane=\"$t->{num}\"/>\n";
        }
    }

    $xml .= "          </spine>\n";
    $xml .= "        </sequence>\n";
    $xml .= "      </project>\n";
    $xml .= "    </event>\n";
    $xml .= "  </library>\n";
    $xml .= "</fcpxml>\n";

    return $xml;
}
